"""Local AI demo persistence for the team's existing routine/workout HTTP contract.

Authentication stays in Spring. These general examples are not photo diagnoses,
and this store is deliberately separate from the team's production database.
"""
from datetime import date, datetime, timedelta, timezone
import json
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Body, Request
from fastapi.responses import Response
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

from bridge.api import BridgeError, now
from routine_preview import DAYS

SOURCE = 'https://www.nhs.uk/live-well/exercise/strength-exercises/'
CATALOG = {
    910001: ('벽 밀기', 'chest', 'bodyweight', '안정된 벽에 손을 대고 편안한 범위에서 천천히 팔을 굽혔다 펴세요.'),
    910002: ('가벼운 물병 팔 굽히기', 'arm', 'dumbbell', '가벼운 물병을 잡고 팔꿈치를 몸 가까이 둔 채 천천히 굽혔다 펴세요.'),
    910003: ('의자 앉았다 일어나기', 'leg', 'bodyweight', '바퀴 없이 미끄러지지 않는 의자에서 천천히 일어나고 앉으세요.'),
    910004: ('의자 잡고 뒤꿈치 들기', 'leg', 'bodyweight', '안정된 의자 등받이를 잡고 편안한 범위에서 뒤꿈치를 천천히 들었다 내리세요.'),
}
MAX_ID = 2**53 - 1


class Input(BaseModel):
    model_config = ConfigDict(extra='forbid')


class PlanInput(Input):
    analysis_id: int = Field(ge=1, le=MAX_ID, strict=True)
    start_date: str | None = None
    cautions: list[str] | None = Field(default=None, max_length=10)


class StartInput(Input):
    exercise_id: int = Field(ge=1, le=MAX_ID, strict=True)
    routine_id: int | None = Field(default=None, ge=1, le=MAX_ID, strict=True)


class SetInput(Input):
    client_set_id: str = Field(min_length=1, max_length=80, pattern=r'^[A-Za-z0-9_-]+$')
    set_no: int = Field(ge=1, le=100, strict=True)
    weight_kg: float = Field(ge=0, le=500, strict=True, allow_inf_nan=False)
    reps: int = Field(ge=1, le=100, strict=True)
    is_done: bool = Field(default=True, strict=True)
    rest_sec: int | None = Field(default=None, ge=0, le=3600, strict=True)


class SetUpdate(Input):
    version: int = Field(ge=1, le=MAX_ID, strict=True)
    weight_kg: float | None = Field(default=None, ge=0, le=500, strict=True, allow_inf_nan=False)
    reps: int | None = Field(default=None, ge=1, le=100, strict=True)
    is_done: bool | None = Field(default=None, strict=True)
    rest_sec: int | None = Field(default=None, ge=0, le=3600, strict=True)

    @model_validator(mode='after')
    def nonnull_updates(self):
        if any(getattr(self, key) is None for key in self.model_fields_set - {'rest_sec'}):
            raise ValueError('Null update')
        return self


def checked(model, body):
    try:
        return model.model_validate(body)
    except ValidationError as exc:
        raise BridgeError('VALIDATION_FAILED', '입력 항목과 범위를 확인해 주세요.', 422) from exc


def day(value):
    try:
        parsed = date.fromisoformat(value)
        if parsed.isoformat() != value:
            raise ValueError('Use YYYY-MM-DD')
        return parsed
    except (ValueError, TypeError) as exc:
        raise BridgeError('VALIDATION_FAILED', '날짜는 YYYY-MM-DD 형식이어야 합니다.', 422) from exc


def today():
    return datetime.now(ZoneInfo('Asia/Seoul')).date()


def exercise(eid):
    if eid not in CATALOG:
        raise BridgeError('NOT_FOUND', '시연 운동을 찾지 못했어요.', 404)
    name, part, equipment, instruction = CATALOG[eid]
    return {'exercise_id': eid, 'name': name, 'target_part': part, 'equipment': equipment,
            'difficulty': 1, 'min_sets': 1, 'max_sets': 2, 'media_url': None,
            'description': instruction, 'source_url': SOURCE}


class WorkoutStore:
    def __init__(self, service):
        self.service = service
        with service.db() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS demo_routines (
                  id INTEGER PRIMARY KEY AUTOINCREMENT, uid INTEGER NOT NULL,
                  analysis_id INTEGER NOT NULL, scheduled_date TEXT NOT NULL,
                  payload TEXT NOT NULL, skipped INTEGER NOT NULL DEFAULT 0,
                  UNIQUE(uid, scheduled_date));
                CREATE TABLE IF NOT EXISTS demo_logs (
                  id INTEGER PRIMARY KEY AUTOINCREMENT, uid INTEGER NOT NULL,
                  exercise_id INTEGER NOT NULL, routine_id INTEGER,
                  started_at TEXT NOT NULL, completed_at TEXT, workout_date TEXT NOT NULL,
                  status TEXT NOT NULL DEFAULT 'in_progress', duration_sec INTEGER,
                  memo TEXT);
                CREATE INDEX IF NOT EXISTS demo_logs_owner ON demo_logs(uid,workout_date);
                CREATE TABLE IF NOT EXISTS demo_sets (
                  id INTEGER PRIMARY KEY AUTOINCREMENT, log_id INTEGER NOT NULL,
                  client_set_id TEXT NOT NULL, set_no INTEGER NOT NULL,
                  weight_kg REAL NOT NULL, reps INTEGER NOT NULL, is_done INTEGER NOT NULL,
                  rest_sec INTEGER, version INTEGER NOT NULL DEFAULT 1,
                  UNIQUE(log_id,client_set_id), UNIQUE(log_id,set_no));
            ''')

    def owned(self, db, table, uid, ident):
        if table not in {'demo_routines', 'demo_logs'}:
            raise ValueError('Invalid table')
        if type(ident) is not int or not 1 <= ident <= MAX_ID:
            raise BridgeError('NOT_FOUND', '기록을 찾지 못했어요.', 404)
        row = db.execute(f'SELECT * FROM {table} WHERE id=? AND uid=?', (ident, uid)).fetchone()
        if row is None:
            raise BridgeError('NOT_FOUND', '기록을 찾지 못했어요.', 404)
        return row

    def require_active(self, row):
        if row['status'] != 'in_progress':
            raise BridgeError('WORKOUT_NOT_ACTIVE', '진행 중인 운동에만 기록할 수 있어요.', 409)
        age = datetime.now(timezone.utc) - datetime.fromisoformat(row['started_at'])
        if age >= timedelta(hours=6):
            raise BridgeError('WORKOUT_EXPIRED', '시작한 지 6시간이 지났습니다. 새 운동을 시작하세요.', 409)

    def generate(self, uid, request, profile):
        start = day(request.start_date) if request.start_date else today()
        if not today() <= start <= today() + timedelta(days=31):
            raise BridgeError('VALIDATION_FAILED', '시작일은 오늘부터 31일 안으로 선택하세요.', 422)
        if request.cautions:
            raise BridgeError('CAUTION_REQUIRES_REVIEW', '주의 항목이 있어 일반 운동 예시 생성을 보류했어요.', 409)
        if (type(profile.get('age')) is not int or not 18 <= profile['age'] <= 100
                or type(profile.get('weekly_frequency')) is not int
                or profile['weekly_frequency'] not in DAYS
                or profile.get('goal_type') not in {'muscle', 'diet', 'posture'}):
            raise BridgeError('PROFILE_REQUIRED', '성인용 신체정보와 운동 목표·주간 횟수를 확인하세요.', 422)
        with self.service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            analysis = db.execute('SELECT status FROM analyses WHERE id=? AND uid=?', (request.analysis_id, uid)).fetchone()
            if analysis is None:
                raise BridgeError('NOT_FOUND', '본인의 분석을 선택하세요.', 404)
            if analysis['status'] != 'done':
                raise BridgeError('ANALYSIS_NOT_READY', '완료된 분석이 필요합니다.', 409)
            identifiers = []
            selected_dates = {(start + timedelta(days=offset)).isoformat() for offset in DAYS[profile['weekly_frequency']]}
            # Regenerate only unstarted plans; preserve every recorded workout.
            for old in db.execute('SELECT id,scheduled_date FROM demo_routines WHERE uid=? AND scheduled_date BETWEEN ? AND ?',
                    (uid, start.isoformat(), (start + timedelta(days=6)).isoformat())).fetchall():
                recorded = db.execute('SELECT id FROM demo_logs WHERE routine_id=?', (old['id'],)).fetchone()
                if old['scheduled_date'] not in selected_dates and not recorded:
                    db.execute('DELETE FROM demo_routines WHERE id=?', (old['id'],))
            for index, offset in enumerate(DAYS[profile['weekly_frequency']]):
                scheduled = (start + timedelta(days=offset)).isoformat()
                existing = db.execute('SELECT id FROM demo_routines WHERE uid=? AND scheduled_date=?', (uid, scheduled)).fetchone()
                if existing:
                    recorded = db.execute('SELECT id FROM demo_logs WHERE routine_id=?', (existing['id'],)).fetchone()
                    if recorded:
                        identifiers.append(existing['id'])
                        continue
                upper = index % 2 == 0
                goal = {'muscle': '기초 근력 동작', 'diet': '규칙적인 활동 습관', 'posture': '편안한 움직임 습관'}[profile['goal_type']]
                reason = f'{goal} 목표와 주 {profile["weekly_frequency"]}회 설정으로 구성한 기본 예시입니다. 사진의 부족 부위 판정은 사용하지 않았습니다.'
                payload = {'title': f'{"상체" if upper else "하체"} · 기본 운동 예시',
                    'target_part': 'chest' if upper else 'leg', 'estimated_minutes': 10,
                    'items': [{'order_no': n + 1, 'exercise': exercise(eid), 'target_sets': 1,
                        'target_reps': 5, 'target_weight_kg': None, 'rest_sec': 60,
                        'reason': reason} for n, eid in enumerate((910001, 910002) if upper else (910003, 910004))],
                    'generation': {'source': 'rule_based_demo_general_example', 'model': None,
                        'photo_measurements_used': False, 'goal_photo_required': False,
                        'cautions_status': 'none_reported' if request.cautions == [] else 'not_collected',
                        'profile_goal': profile['goal_type'], 'weekly_frequency': profile['weekly_frequency'],
                        'rule_set_review_status': 'not_professionally_validated', 'source_url': SOURCE,
                        'note': '세트·휴식·시간은 시연 기본값이며 개인별 적합성·효과를 검증한 처방이 아닙니다. 통증이나 불편이 생기면 중단하세요.'}}
                if existing:
                    rid = existing['id']
                    db.execute('UPDATE demo_routines SET analysis_id=?,payload=?,skipped=0 WHERE id=?',
                        (request.analysis_id, json.dumps(payload, ensure_ascii=False), rid))
                else:
                    rid = db.execute('INSERT INTO demo_routines(uid,analysis_id,scheduled_date,payload) VALUES(?,?,?,?)',
                        (uid, request.analysis_id, scheduled, json.dumps(payload, ensure_ascii=False))).lastrowid
                identifiers.append(rid)
            return {'routines': [self.routine(db, uid, rid) for rid in identifiers],
                    'source': 'rule_based_demo_general_example', 'saved': True,
                    'store': 'AI_bridge_local', 'photo_measurements_used': False}

    def routine(self, db, uid, rid):
        row = self.owned(db, 'demo_routines', uid, rid)
        result = json.loads(row['payload'])
        done = {r['exercise_id'] for r in db.execute('''SELECT DISTINCT l.exercise_id FROM demo_logs l
            JOIN demo_sets s ON s.log_id=l.id WHERE l.uid=? AND l.routine_id=?
            AND l.status='completed' AND s.is_done=1''', (uid, rid))}
        for item in result['items']:
            item['item_id'] = rid * 10 + item['order_no']
            item['done'] = item['exercise']['exercise_id'] in done
        complete = all(item['done'] for item in result['items'])
        result.update(routine_id=rid, analysis_id=row['analysis_id'], scheduled_date=row['scheduled_date'],
            status='done' if complete else 'skipped' if row['skipped'] else 'planned')
        return result

    def summary(self, routine):
        return {key: routine[key] for key in ('routine_id', 'title', 'target_part', 'estimated_minutes', 'status')} | {
            'item_count': len(routine['items']), 'done_count': sum(item['done'] for item in routine['items'])}

    def weekly(self, uid, start):
        if start.weekday() != 0:
            raise BridgeError('VALIDATION_FAILED', '주 시작일은 월요일이어야 합니다.', 422)
        with self.service.db() as db:
            rows = db.execute('SELECT * FROM demo_routines WHERE uid=? AND scheduled_date BETWEEN ? AND ?',
                (uid, start.isoformat(), (start + timedelta(days=6)).isoformat())).fetchall()
            lookup = {r['scheduled_date']: self.routine(db, uid, r['id']) for r in rows}
        days = []
        for offset in range(7):
            key = (start + timedelta(days=offset)).isoformat()
            routine = lookup.get(key)
            days.append({'date': key, 'is_rest_day': routine is None,
                         'routine': self.summary(routine) if routine else None})
        return {'week_start': start.isoformat(), 'days': days}

    def log(self, db, uid, lid):
        row = self.owned(db, 'demo_logs', uid, lid)
        sets = [dict(s) for s in db.execute('SELECT * FROM demo_sets WHERE log_id=? ORDER BY set_no', (lid,))]
        for entry in sets:
            entry['set_id'] = entry.pop('id');entry.pop('log_id');entry['is_done'] = bool(entry['is_done'])
        done = [s for s in sets if s['is_done']]
        return {'log_id': lid, 'exercise': exercise(row['exercise_id']), 'routine_id': row['routine_id'],
            'started_at': row['started_at'], 'completed_at': row['completed_at'], 'workout_date': row['workout_date'],
            'status': row['status'], 'duration_sec': row['duration_sec'], 'memo': row['memo'], 'sets': sets,
            'set_count': len(done), 'total_volume_kg': round(sum(s['weight_kg'] * s['reps'] for s in done), 2)}

    def start(self, uid, body):
        exercise(body.exercise_id)
        with self.service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            db.execute("UPDATE demo_logs SET status='aborted' WHERE uid=? AND status='in_progress' AND started_at<?",
                (uid, (datetime.now(timezone.utc) - timedelta(hours=6)).isoformat()))
            if body.routine_id is not None:
                routine = self.routine(db, uid, body.routine_id)
                if routine['status'] == 'skipped':
                    raise BridgeError('ROUTINE_SKIPPED', '건너뛴 플랜을 먼저 되돌리세요.', 409)
                if body.exercise_id not in {i['exercise']['exercise_id'] for i in routine['items']}:
                    raise BridgeError('EXERCISE_MISMATCH', '이 플랜에 없는 운동입니다.', 422)
            row = db.execute("SELECT id FROM demo_logs WHERE uid=? AND exercise_id=? AND routine_id IS ? AND status='in_progress' ORDER BY id DESC LIMIT 1",
                (uid, body.exercise_id, body.routine_id)).fetchone()
            if row:
                return self.log(db, uid, row['id']), False
            lid = db.execute('INSERT INTO demo_logs(uid,exercise_id,routine_id,started_at,workout_date) VALUES(?,?,?,?,?)',
                (uid, body.exercise_id, body.routine_id, now(), today().isoformat())).lastrowid
            return self.log(db, uid, lid), True

    def add_set(self, uid, lid, body):
        with self.service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            row = self.owned(db, 'demo_logs', uid, lid)
            existing = db.execute('SELECT * FROM demo_sets WHERE log_id=? AND client_set_id=?', (lid, body.client_set_id)).fetchone()
            if existing:
                values = body.model_dump()
                if any(existing[key] != value for key, value in values.items()):
                    raise BridgeError('IDEMPOTENCY_CONFLICT', '같은 세트 식별자에 다른 값이 있습니다.', 409)
                return self.log(db, uid, lid)
            self.require_active(row)
            if db.execute('SELECT id FROM demo_sets WHERE log_id=? AND set_no=?', (lid, body.set_no)).fetchone():
                raise BridgeError('SET_NUMBER_CONFLICT', '같은 세트 번호가 이미 있습니다.', 409)
            db.execute('INSERT INTO demo_sets(log_id,client_set_id,set_no,weight_kg,reps,is_done,rest_sec) VALUES(?,?,?,?,?,?,?)',
                (lid, body.client_set_id, body.set_no, body.weight_kg, body.reps, int(body.is_done), body.rest_sec))
            return self.log(db, uid, lid)

    def complete(self, uid, lid, memo):
        if memo is not None and (not isinstance(memo, str) or len(memo) > 1000):
            raise BridgeError('VALIDATION_FAILED', '메모는 1000자 이하여야 합니다.', 422)
        with self.service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            row = self.owned(db, 'demo_logs', uid, lid)
            if row['status'] != 'completed':
                self.require_active(row)
                log = self.log(db, uid, lid)
                if not log['set_count']:
                    raise BridgeError('NO_COMPLETED_SETS', '완료한 세트를 한 개 이상 기록하세요.', 409)
                seconds = int((datetime.now(timezone.utc) - datetime.fromisoformat(row['started_at'])).total_seconds())
                db.execute("UPDATE demo_logs SET status='completed',completed_at=?,duration_sec=?,memo=? WHERE id=?",
                    (now(), max(0, seconds), memo, lid))
            result = self.log(db, uid, lid)
            if row['routine_id'] is not None:
                routine = self.routine(db, uid, row['routine_id'])
                result.update(routine_status=routine['status'], routine_progress={
                    'done': sum(item['done'] for item in routine['items']), 'total': len(routine['items'])})
            return result


def install_workouts(app, service):
    store = WorkoutStore(service)
    service.workouts = store
    router = APIRouter()

    def uid(request):
        user = service.user(request, cleanup=True)
        if user.get('onboarding_completed') is not True:
            raise BridgeError('ONBOARDING_REQUIRED', '신체정보를 먼저 입력해 주세요.', 403)
        return user['user_id']

    @router.post('/api/routines', status_code=201)
    def generate(request: Request, body: dict = Body()):
        owner = service.user(request, True)['user_id']
        validated = checked(PlanInput, body)
        response = service.backend_request('GET', '/api/users/me/profile', request.headers.get('authorization'))
        if response.status_code != 200:
            raise BridgeError('PROFILE_REQUIRED', '신체정보를 먼저 입력해 주세요.', 422 if response.status_code == 404 else 503)
        try:
            profile = response.json()
            if not isinstance(profile, dict):raise ValueError('Invalid profile')
        except ValueError as exc:
            raise BridgeError('AUTH_SERVER_UNAVAILABLE', '프로필 응답을 읽지 못했어요.', 503) from exc
        return store.generate(owner, validated, profile)

    @router.get('/api/routines/weekly')
    def weekly(request: Request, week_start: str):
        return store.weekly(uid(request), day(week_start))

    @router.get('/api/routines/today')
    def today_routine(request: Request):
        owner = uid(request)
        with service.db() as db:
            row = db.execute('SELECT id FROM demo_routines WHERE uid=? AND scheduled_date=?', (owner, today().isoformat())).fetchone()
            result = store.routine(db, owner, row['id']) if row else None
        return {'date': today().isoformat(), 'is_rest_day': result is None, 'routine': result}

    @router.get('/api/routines/{routine_id}')
    def routine(request: Request, routine_id: int):
        owner = uid(request)
        with service.db() as db:return store.routine(db, owner, routine_id)

    @router.patch('/api/routines/{routine_id}')
    def routine_status(request: Request, routine_id: int, body: dict = Body()):
        owner = uid(request)
        if set(body) != {'status'} or body['status'] not in ('planned', 'skipped'):
            raise BridgeError('VALIDATION_FAILED', '건너뛰기 또는 되돌리기만 가능합니다.', 422)
        with service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            current = store.routine(db, owner, routine_id)
            if current['status'] == 'done':
                raise BridgeError('ROUTINE_COMPLETED', '완료한 플랜은 건너뛸 수 없습니다.', 409)
            db.execute('UPDATE demo_routines SET skipped=? WHERE id=?', (body['status'] == 'skipped', routine_id))
            return store.routine(db, owner, routine_id)

    @router.get('/api/exercises')
    def exercises(request: Request, q: str = '', target_part: str | None = None,
                  equipment: str | None = None, difficulty: int | None = None, page: int = 1, page_size: int = 20):
        uid(request)
        if page < 1 or not 1 <= page_size <= 100:raise BridgeError('VALIDATION_FAILED', '페이지 범위를 확인하세요.', 422)
        items = [exercise(eid) for eid in CATALOG]
        items = [item for item in items if q.casefold() in item['name'].casefold()
            and (target_part is None or item['target_part'] == target_part)
            and (equipment is None or item['equipment'] == equipment)
            and (difficulty is None or item['difficulty'] == difficulty)]
        return {'items': items[(page-1)*page_size:page*page_size], 'page': page, 'total': len(items)}

    @router.get('/api/exercises/{exercise_id}')
    def exercise_detail(request: Request, exercise_id: int):
        uid(request);return exercise(exercise_id)

    @router.post('/api/workout-logs')
    def start(request: Request, body: dict = Body()):
        result, created = store.start(uid(request), checked(StartInput, body))
        from fastapi.responses import JSONResponse
        return JSONResponse(result, status_code=201 if created else 200)

    @router.get('/api/workout-logs/{log_id}')
    def log_detail(request: Request, log_id: int):
        owner = uid(request)
        with service.db() as db:return store.log(db, owner, log_id)

    @router.post('/api/workout-logs/{log_id}/sets')
    def add_set(request: Request, log_id: int, body: dict = Body()):
        return store.add_set(uid(request), log_id, checked(SetInput, body))

    @router.patch('/api/workout-logs/{log_id}/sets/{set_id}')
    def update_set(request: Request, log_id: int, set_id: int, body: dict = Body()):
        owner = uid(request);values = checked(SetUpdate, body)
        if not 1 <= set_id <= MAX_ID:
            raise BridgeError('NOT_FOUND', '세트를 찾지 못했어요.', 404)
        with service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            log_row = store.owned(db, 'demo_logs', owner, log_id)
            row = db.execute('SELECT * FROM demo_sets WHERE id=? AND log_id=?', (set_id, log_id)).fetchone()
            if row is None:raise BridgeError('NOT_FOUND', '세트를 찾지 못했어요.', 404)
            if row['version'] != values.version:raise BridgeError('VERSION_CONFLICT', '기록을 다시 불러온 뒤 수정하세요.', 409)
            merged = dict(row) | values.model_dump(exclude_unset=True, exclude={'version'})
            if log_row['status'] == 'completed' and not merged['is_done'] and row['is_done']:
                if db.execute('SELECT COUNT(*) FROM demo_sets WHERE log_id=? AND is_done=1', (log_id,)).fetchone()[0] <= 1:
                    raise BridgeError('LAST_COMPLETED_SET', '완료 기록의 마지막 세트입니다. 운동 기록 전체 삭제를 사용하세요.', 409)
            db.execute('UPDATE demo_sets SET weight_kg=?,reps=?,is_done=?,rest_sec=?,version=version+1 WHERE id=?',
                (merged['weight_kg'], merged['reps'], merged['is_done'], merged['rest_sec'], set_id))
            return store.log(db, owner, log_id)

    @router.delete('/api/workout-logs/{log_id}/sets/{set_id}', status_code=204)
    def delete_set(request: Request, log_id: int, set_id: int):
        owner = uid(request)
        if not 1 <= set_id <= MAX_ID:
            raise BridgeError('NOT_FOUND', '세트를 찾지 못했어요.', 404)
        with service.db() as db:
            db.execute('BEGIN IMMEDIATE')
            log_row = store.owned(db, 'demo_logs', owner, log_id)
            if log_row['status'] == 'completed':
                entry = db.execute('SELECT is_done FROM demo_sets WHERE id=? AND log_id=?', (set_id, log_id)).fetchone()
                if entry and entry['is_done'] and db.execute('SELECT COUNT(*) FROM demo_sets WHERE log_id=? AND is_done=1', (log_id,)).fetchone()[0] <= 1:
                    raise BridgeError('LAST_COMPLETED_SET', '완료 기록의 마지막 세트입니다. 운동 기록 전체 삭제를 사용하세요.', 409)
            if not db.execute('DELETE FROM demo_sets WHERE id=? AND log_id=?', (set_id, log_id)).rowcount:
                raise BridgeError('NOT_FOUND', '세트를 찾지 못했어요.', 404)
        return Response(status_code=204)

    @router.patch('/api/workout-logs/{log_id}/complete')
    def complete(request: Request, log_id: int, body: dict = Body(default={})):
        if set(body) - {'memo'}:raise BridgeError('VALIDATION_FAILED', '완료 항목을 확인하세요.', 422)
        return store.complete(uid(request), log_id, body.get('memo'))

    @router.delete('/api/workout-logs/{log_id}', status_code=204)
    def delete_log(request: Request, log_id: int):
        owner = service.user(request, cleanup=True)['user_id']
        with service.db() as db:
            db.execute('BEGIN IMMEDIATE');store.owned(db, 'demo_logs', owner, log_id)
            db.execute('DELETE FROM demo_sets WHERE log_id=?', (log_id,))
            db.execute('DELETE FROM demo_logs WHERE id=?', (log_id,))
        return Response(status_code=204)

    @router.get('/api/workout-logs')
    def logs(request: Request, start_date: str, end_date: str, status: str | None = None, page: int = 1, page_size: int = 50):
        owner = uid(request);a, b = day(start_date), day(end_date)
        if not 0 <= (b-a).days < 92 or page < 1 or not 1 <= page_size <= 100 or status not in (None, 'in_progress', 'completed', 'aborted'):
            raise BridgeError('VALIDATION_FAILED', '조회 기간·상태·페이지를 확인하세요.', 422)
        with service.db() as db:
            rows = db.execute('SELECT id FROM demo_logs WHERE uid=? AND workout_date BETWEEN ? AND ? AND (? IS NULL OR status=?) ORDER BY id DESC',
                (owner, a.isoformat(), b.isoformat(), status, status)).fetchall()
            all_logs = [store.log(db, owner, row['id']) for row in rows]
        completed = [log for log in all_logs if log['status'] == 'completed']
        return {'items': all_logs[(page-1)*page_size:page*page_size], 'page': page, 'total': len(all_logs),
            'summary': {'log_count': len(all_logs), 'total_sets': sum(log['set_count'] for log in completed),
                'total_volume_kg': round(sum(log['total_volume_kg'] for log in completed), 2),
                'total_duration_sec': sum(log['duration_sec'] or 0 for log in completed),
                'workout_dates': sorted({log['workout_date'] for log in completed})}}

    app.include_router(router)
    return store
