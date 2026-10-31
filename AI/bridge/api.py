"""Optional Flutter-compatible AI routes. Authentication stays in the unchanged Spring BE."""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import logging
from pathlib import Path
import secrets
import sqlite3
import tempfile
import threading
from urllib.parse import urlparse
import uuid
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Body, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse, Response
import requests

log = logging.getLogger(__name__)


class BridgeError(Exception):
    def __init__(self, code, message, status=400):
        self.code, self.message, self.status = code, message, status
        super().__init__(message)


def now():
    return datetime.now(timezone.utc).isoformat()


class FlutterBridge:
    def __init__(self, directory, backend_url, engine, normalize):
        parsed = urlparse(backend_url)
        if parsed.scheme != 'http' or parsed.hostname not in {'127.0.0.1', 'localhost'} or parsed.username:
            raise ValueError('인증 백엔드는 로컬 Spring 주소만 허용합니다.')
        self.backend = backend_url.rstrip('/')
        self.root = Path(directory).resolve()
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.photos = self.root / 'photos'
        self.photos.mkdir(exist_ok=True)
        self.database = self.root / 'bridge.sqlite3'
        key = self.root / 'photo-signing.key'
        if not key.exists():
            try:
                with key.open('x') as f:
                    f.write(secrets.token_hex(32))
                key.chmod(0o600)
            except FileExistsError:
                pass
        self.secret = key.read_bytes()
        self.engine, self.normalize = engine, normalize
        self.executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix='movid-ai')
        self.capacity = threading.BoundedSemaphore(1)
        with self.db() as db:
            db.executescript('''
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS photos (
                  id INTEGER PRIMARY KEY AUTOINCREMENT, uid INTEGER NOT NULL,
                  type TEXT NOT NULL, side TEXT NOT NULL, file TEXT NOT NULL,
                  created_at TEXT NOT NULL, deleted_at TEXT);
                CREATE TABLE IF NOT EXISTS analyses (
                  id INTEGER PRIMARY KEY AUTOINCREMENT, uid INTEGER NOT NULL,
                  photo_id INTEGER NOT NULL, side_id INTEGER, status TEXT NOT NULL,
                  payload TEXT, error_code TEXT, error_message TEXT,
                  created_at TEXT NOT NULL, completed_at TEXT);
                CREATE UNIQUE INDEX IF NOT EXISTS one_pending_per_user
                  ON analyses(uid) WHERE status='pending';
            ''')
            db.execute("UPDATE analyses SET status='failed', error_code='AI_FAILED', error_message=?, completed_at=? WHERE status='pending'",
                       ('서버가 재시작되어 분석이 중단됐어요. 다시 시도해 주세요.', now()))

    @contextmanager
    def db(self):
        connection = sqlite3.connect(self.database, timeout=10)
        connection.row_factory = sqlite3.Row
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    def close(self):
        self.executor.shutdown(wait=True)

    def backend_request(self, method, path, authorization=None, body=None, query=None):
        headers = {'Accept': 'application/json'}
        if authorization:
            headers['Authorization'] = authorization
        try:
            return requests.request(method, self.backend + path, headers=headers, json=body,
                                    params=query, timeout=10, allow_redirects=False)
        except requests.RequestException as exc:
            raise BridgeError('AUTH_SERVER_UNAVAILABLE', '로그인 서버에 연결하지 못했어요.', 503) from exc

    def user(self, request, ai=False):
        authorization = request.headers.get('authorization', '')
        if not authorization.startswith('Bearer '):
            raise BridgeError('UNAUTHORIZED', '로그인이 필요해요.', 401)
        response = self.backend_request('GET', '/api/users/me', authorization)
        if response.status_code != 200:
            raise BridgeError('UNAUTHORIZED', '로그인 정보를 확인해 주세요.', 401)
        try:
            user = response.json()
            if not isinstance(user, dict):
                raise ValueError('Invalid user response')
        except (ValueError, TypeError) as exc:
            raise BridgeError('AUTH_SERVER_UNAVAILABLE', '사용자 응답을 확인하지 못했어요.', 503) from exc
        if not user.get('onboarding_completed'):
            raise BridgeError('ONBOARDING_REQUIRED', '신체 정보를 먼저 입력해 주세요.', 403)
        if not user.get('body_photo_agreed') or (ai and not user.get('ai_processing_agreed')):
            raise BridgeError('CONSENT_REQUIRED', '사진·AI 처리 동의가 필요해요.', 403)
        if not isinstance(user.get('user_id'), int):
            raise BridgeError('AUTH_SERVER_UNAVAILABLE', '사용자 응답을 확인하지 못했어요.', 503)
        return user

    def owned_photo(self, db, uid, photo_id):
        photo = db.execute('SELECT * FROM photos WHERE id=? AND uid=? AND deleted_at IS NULL', (photo_id, uid)).fetchone()
        if photo is None:
            raise BridgeError('NOT_FOUND', '사진을 찾을 수 없어요.', 404)
        return photo

    def signature(self, photo, expires):
        return hmac.new(self.secret, f"{photo['id']}:{photo['uid']}:{expires}".encode(), hashlib.sha256).hexdigest()

    def photo_view(self, photo, base):
        expires = int(datetime.now(timezone.utc).timestamp()) + 3600
        return {'photo_id': photo['id'], 'type': photo['type'], 'side': photo['side'],
                'url': f"{base}/api/photo-files/{photo['id']}?expires={expires}&signature={self.signature(photo, expires)}",
                'url_expires_at': datetime.fromtimestamp(expires, timezone.utc).isoformat(), 'created_at': photo['created_at']}

    def usage(self, db, user):
        local = datetime.now(ZoneInfo('Asia/Seoul'))
        start = local.replace(hour=0, minute=0, second=0, microsecond=0)
        used = db.execute("SELECT COUNT(*) FROM analyses WHERE uid=? AND created_at>=? AND status!='failed'",
                          (user['user_id'], start.astimezone(timezone.utc).isoformat())).fetchone()[0]
        limit = 10000 if user.get('role') == 'admin' or user.get('email') == 'demo@movid.local' else 3
        return {'used': used, 'limit': limit, 'remaining': max(0, limit-used), 'reset_at': (start+timedelta(days=1)).isoformat()}

    def start(self, user, photo_id, side_id=None, goal_id=None):
        if goal_id is not None:
            raise BridgeError('GOAL_NOT_READY', '현재 AI 연결은 목표 비교를 제공하지 않아요.')
        if not isinstance(photo_id, int) or isinstance(photo_id, bool) or photo_id <= 0:
            raise BridgeError('VALIDATION_FAILED', '정면 사진 ID가 필요해요.')
        if side_id is not None and (not isinstance(side_id, int) or isinstance(side_id, bool) or side_id <= 0):
            raise BridgeError('VALIDATION_FAILED', '측면 사진 ID를 확인하세요.')
        acquired = False
        try:
            with self.db() as db:
                db.execute('BEGIN IMMEDIATE')
                uid = user['user_id']
                photo = self.owned_photo(db, uid, photo_id)
                if photo['type'] != 'current' or photo['side'] != 'front':
                    raise BridgeError('PHOTO_TYPE_MISMATCH', '현재 정면 사진을 선택해 주세요.')
                if side_id is not None:
                    side = self.owned_photo(db, uid, side_id)
                    if side['type'] != 'current' or side['side'] != 'side':
                        raise BridgeError('PHOTO_TYPE_MISMATCH', '측면 사진 형식이 맞지 않아요.')
                cached = db.execute("SELECT * FROM analyses WHERE uid=? AND photo_id=? AND side_id IS ? AND status='done' ORDER BY id DESC LIMIT 1",
                                    (uid, photo_id, side_id)).fetchone()
                if cached:
                    return self.ticket(cached)
                if db.execute("SELECT id FROM analyses WHERE uid=? AND status='pending'", (uid,)).fetchone():
                    raise BridgeError('ANALYSIS_IN_PROGRESS', '진행 중인 분석을 먼저 확인해 주세요.', 409)
                if self.usage(db, user)['remaining'] == 0:
                    raise BridgeError('ANALYSIS_QUOTA_EXCEEDED', '오늘의 분석 횟수를 모두 사용했어요.', 429)
                if not self.capacity.acquire(blocking=False):
                    raise BridgeError('AI_BUSY', '다른 사진을 분석 중이에요. 잠시 후 다시 시도해 주세요.', 503)
                acquired = True
                cursor = db.execute("INSERT INTO analyses(uid,photo_id,side_id,status,created_at) VALUES(?,?,?,'pending',?)",
                                    (uid, photo_id, side_id, now()))
                analysis = db.execute('SELECT * FROM analyses WHERE id=?', (cursor.lastrowid,)).fetchone()
        except Exception:
            if acquired:
                self.capacity.release()
            raise
        try:
            self.executor.submit(self.process, analysis['id'], photo['file'])
        except Exception:
            self.capacity.release()
            self.fail(analysis['id'], 'AI_FAILED', '분석을 시작하지 못했어요.')
        return self.ticket(analysis)

    @staticmethod
    def ticket(row):
        return {'analysis_id': row['id'], 'status': row['status'], 'created_at': row['created_at'], 'poll_after_ms': 2000}

    def fail(self, analysis_id, code, message):
        with self.db() as db:
            db.execute("UPDATE analyses SET status='failed', error_code=?, error_message=?, completed_at=? WHERE id=? AND status='pending'",
                       (code, message, now(), analysis_id))

    def process(self, analysis_id, filename):
        try:
            with tempfile.TemporaryDirectory(prefix='analysis-', dir=self.root) as directory:
                result = self.engine().analyze(self.photos / filename, Path(directory))
                # Preserve actual measurements; never invent a balance score or muscle grade.
                if result.get('status') != 'done' or not isinstance(result.get('measures'), dict):
                    raise ValueError('Invalid AI result')
                result.pop('debug_image_base64', None)
                payload = json.dumps(result, ensure_ascii=False, allow_nan=False)
                with self.db() as db:
                    db.execute("UPDATE analyses SET status='done', payload=?, completed_at=? WHERE id=? AND status='pending'",
                               (payload, now(), analysis_id))
        except Exception as exc:
            code = getattr(exc, 'code', 'AI_FAILED')
            message = getattr(exc, 'message', 'AI 분석을 완료하지 못했어요.')
            log.warning('Analysis %s failed: %s', analysis_id, type(exc).__name__)
            self.fail(analysis_id, code, message)
        finally:
            self.capacity.release()

    def detail(self, db, uid, analysis_id):
        row = db.execute('SELECT * FROM analyses WHERE id=? AND uid=?', (analysis_id, uid)).fetchone()
        if row is None:
            raise BridgeError('NOT_FOUND', '분석을 찾을 수 없어요.', 404)
        if row['status'] == 'pending' and (datetime.now(timezone.utc)-datetime.fromisoformat(row['created_at'])).total_seconds() > 90:
            db.execute("UPDATE analyses SET status='failed',error_code='AI_TIMEOUT',error_message=?,completed_at=? WHERE id=?",
                       ('분석 시간이 초과됐어요.', now(), analysis_id))
            row = db.execute('SELECT * FROM analyses WHERE id=?', (analysis_id,)).fetchone()
        result = json.loads(row['payload']) if row['payload'] else {}
        result.update(self.ticket(row))
        result.update({'source': 'photo', 'photo_id': row['photo_id'], 'side_photo_id': row['side_id'],
                       'goal_body_id': None, 'completed_at': row['completed_at'], 'error_code': row['error_code'],
                       'error_message': row['error_message']})
        result.setdefault('measures', None)
        result.setdefault('judgements', [])
        return result


def install(app, directory, backend_url, normalize):
    service = FlutterBridge(directory, backend_url, lambda: app.state.engine, normalize)
    app.state.flutter_bridge = service
    router = APIRouter()

    @app.exception_handler(BridgeError)
    async def failure(request, exc):
        return JSONResponse({'code': exc.code, 'message': exc.message, 'status': exc.status, 'fields': None}, status_code=exc.status)

    def proxy(request, body):
        response = service.backend_request(request.method, request.url.path, request.headers.get('authorization'), body, dict(request.query_params))
        return Response(response.content, status_code=response.status_code,
                        media_type=response.headers.get('content-type', 'application/json'), headers={'Cache-Control': 'no-store'})

    @router.api_route('/api/auth/{tail:path}', methods=['POST', 'GET'])
    def auth(request: Request, tail: str, body: dict | None = Body(default=None)):
        return proxy(request, body)

    @router.api_route('/api/users', methods=['POST'])
    @router.api_route('/api/users/{tail:path}', methods=['GET', 'PATCH', 'POST', 'DELETE'])
    def users(request: Request, tail: str = '', body: dict | None = Body(default=None)):
        return proxy(request, body)

    @router.post('/api/photos', status_code=201)
    def upload(request: Request, image: UploadFile = File(), type: str = Form(default='current'), side: str = Form(default='front')):
        user = service.user(request)
        if type not in {'current', 'goal'} or side not in {'front', 'side', 'back'}:
            raise BridgeError('VALIDATION_FAILED', '사진 종류를 확인해 주세요.')
        with service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            if db.execute('SELECT COUNT(*) FROM photos WHERE uid=? AND deleted_at IS NULL', (user['user_id'],)).fetchone()[0] >= 20:
                raise BridgeError('PHOTO_LIMIT_EXCEEDED', '사진은 최대 20장 보관할 수 있어요.')
            with tempfile.TemporaryDirectory(dir=service.root) as directory:
                try:
                    normalized = service.normalize(image, Path(directory))
                except HTTPException as exc:
                    raise BridgeError('VALIDATION_FAILED', '올바른 10MB 이하 JPG/PNG 사진을 사용해 주세요.') from exc
                filename = uuid.uuid4().hex + '.jpg'
                target = service.photos / filename
                target.write_bytes(normalized.read_bytes())
            try:
                cursor = db.execute('INSERT INTO photos(uid,type,side,file,created_at) VALUES(?,?,?,?,?)',
                                    (user['user_id'], type, side, filename, now()))
                photo = db.execute('SELECT * FROM photos WHERE id=?', (cursor.lastrowid,)).fetchone()
                return service.photo_view(photo, str(request.base_url).rstrip('/'))
            except Exception:
                target.unlink(missing_ok=True)
                raise

    @router.get('/api/photos')
    def photos(request: Request, type: str = 'current', page: int = 1, page_size: int = 20):
        user = service.user(request)
        if page < 1 or not 1 <= page_size <= 100:
            raise BridgeError('VALIDATION_FAILED', '페이지 범위를 확인하세요.')
        with service.db() as db:
            rows = db.execute('SELECT * FROM photos WHERE uid=? AND type=? AND deleted_at IS NULL ORDER BY id DESC', (user['user_id'], type)).fetchall()
        return {'items': [service.photo_view(row, str(request.base_url).rstrip('/')) for row in rows[(page-1)*page_size:page*page_size]], 'total': len(rows), 'page': page}

    @router.get('/api/photo-files/{photo_id}')
    def photo_file(photo_id: int, expires: int, signature: str):
        with service.db() as db:
            row = db.execute('SELECT * FROM photos WHERE id=? AND deleted_at IS NULL', (photo_id,)).fetchone()
        if row is None or expires < int(datetime.now(timezone.utc).timestamp()) or not hmac.compare_digest(service.signature(row, expires), signature):
            raise BridgeError('NOT_FOUND', '사진을 찾을 수 없어요.', 404)
        path = service.photos / row['file']
        if not path.is_file():
            raise BridgeError('NOT_FOUND', '사진을 찾을 수 없어요.', 404)
        return Response(path.read_bytes(), media_type='image/jpeg', headers={'Cache-Control': 'no-store'})

    def delete(request, photo_id=None, type='current'):
        user = service.user(request)
        with service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            rows = [service.owned_photo(db, user['user_id'], photo_id)] if photo_id is not None else db.execute('SELECT * FROM photos WHERE uid=? AND type=? AND deleted_at IS NULL', (user['user_id'], type)).fetchall()
            deleted = skipped = 0
            for row in rows:
                busy = db.execute("SELECT id FROM analyses WHERE uid=? AND status='pending' AND (photo_id=? OR side_id=?)", (user['user_id'], row['id'], row['id'])).fetchone()
                if busy:
                    skipped += 1
                    continue
                (service.photos / row['file']).unlink(missing_ok=True)
                db.execute('UPDATE photos SET deleted_at=? WHERE id=?', (now(), row['id']))
                deleted += 1
            return {'deleted_count': deleted, 'skipped_count': skipped}

    @router.delete('/api/photos/{photo_id}', status_code=204)
    def delete_one(request: Request, photo_id: int):
        if delete(request, photo_id)['skipped_count']:
            raise BridgeError('ANALYSIS_IN_PROGRESS', '분석 중인 사진은 삭제할 수 없어요.', 409)
        return Response(status_code=204)

    @router.delete('/api/photos')
    def delete_all(request: Request, type: str = 'current'):
        return delete(request, type=type)

    @router.get('/api/body-analyses/usage')
    def usage(request: Request):
        user = service.user(request, True)
        with service.db() as db:
            return service.usage(db, user)

    @router.post('/api/body-analyses/photo', status_code=202)
    def start(request: Request, body: dict = Body()):
        return service.start(service.user(request, True), body.get('photo_id'), body.get('side_photo_id'), body.get('goal_body_id'))

    @router.get('/api/body-analyses/{analysis_id}')
    def detail(request: Request, analysis_id: int):
        user = service.user(request, True)
        with service.db() as db:
            return service.detail(db, user['user_id'], analysis_id)

    @router.get('/api/body-analyses')
    def history(request: Request, page: int = 1, page_size: int = 20):
        user = service.user(request, True)
        if page < 1 or not 1 <= page_size <= 100:
            raise BridgeError('VALIDATION_FAILED', '페이지 범위를 확인하세요.')
        with service.db() as db:
            rows = db.execute('SELECT * FROM analyses WHERE uid=? ORDER BY id DESC', (user['user_id'],)).fetchall()
        return {'items': [{'analysis_id': row['id'], 'status': row['status'], 'created_at': row['created_at'], 'balance_score': None, 'body_type': None} for row in rows[(page-1)*page_size:page*page_size]], 'total': len(rows), 'page': page}

    @router.get('/api/goal-bodies')
    def goal(request: Request):
        service.user(request, True)
        raise BridgeError('GOAL_NOT_FOUND', '등록한 목표 체형이 없어요.', 404)

    @router.post('/api/routines')
    def routine(request: Request):
        service.user(request, True)
        raise BridgeError('GOAL_NOT_READY', '현재 연결은 운동 추천을 제공하지 않아요.')

    app.include_router(router)
    return service
