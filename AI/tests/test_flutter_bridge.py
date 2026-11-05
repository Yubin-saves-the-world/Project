"""Compatibility checks for the unchanged Flutter photo/analysis contract."""
import io
from contextlib import contextmanager
from pathlib import Path
from types import SimpleNamespace
import tempfile
import time
import threading
import unittest
from unittest.mock import patch, MagicMock

from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

from app import save_image
from bridge.api import install, FlutterBridge
from integration import AnalysisFailure


class FakeEngine:
    failure = False
    calls = 0

    def analyze(self, path, directory, **kwargs):
        self.last_kwargs = kwargs
        self.calls += 1
        if self.failure:
            raise AnalysisFailure('IMAGE_BLURRY', '사진이 흐려요.')
        assert Path(path).is_file()
        return {'status': 'done', 'measurement_version': 'pixel-dino-v1',
                'measures': {'shoulder_tilt_deg': .4, 'pelvis_tilt_deg': 1.2,
                             'neck_forward_deg': None, 'shoulder_hip_ratio': 1.7,
                             'torso_leg_ratio': .7, 'unavailable': []},
                'balance_score': None, 'body_type': None, 'judgements': [],
                'debug_image_base64': 'not persisted', 'dinov3': {'parts': []}}


def image():
    stream = io.BytesIO()
    Image.new('RGB', (200, 400), 'white').save(stream, format='JPEG')
    return ('photo.jpg', stream.getvalue(), 'image/jpeg')


class FlutterBridgeTests(unittest.TestCase):
    def test_malformed_user_id_and_nonboolean_consents_are_rejected(self):
        user = {'user_id': 1, 'onboarding_completed': True,
                'body_photo_agreed': True, 'ai_processing_agreed': True}
        cases = [({'user_id': value}, 503) for value in (True, 0, -1, '1', 10**100)]
        cases += [({'body_photo_agreed': 'true'}, 403),
                  ({'ai_processing_agreed': 1}, 403),
                  ({'onboarding_completed': 'true'}, 403)]
        for changed, status in cases:
            response = SimpleNamespace(status_code=200, json=lambda: {**user, **changed})
            with patch('bridge.api.requests.Session.request', return_value=response):
                actual = self.client.get('/api/body-analyses/usage', headers=self.auth)
            self.assertEqual(actual.status_code, status)

    def test_auth_transport_disables_environment_proxy_and_redirects(self):
        session = MagicMock()
        session.__enter__.return_value = session
        with patch('bridge.api.requests.Session', return_value=session):
            self.service.backend_request('GET', '/api/users/me', 'Bearer test')
        self.assertFalse(session.trust_env)
        self.assertFalse(session.request.call_args.kwargs['allow_redirects'])
        self.assertEqual(session.request.call_args.args[1], 'http://127.0.0.1:8082/api/users/me')

    def test_huge_ids_and_pages_do_not_reach_sqlite_as_overflows(self):
        huge = 10**100
        for path in (f'/api/body-analyses/{huge}', f'/api/photo-files/{huge}?expires=1&signature=x'):
            self.assertEqual(self.client.get(path, headers=self.auth).status_code, 404)
        self.assertEqual(self.client.delete(f'/api/photos/{huge}', headers=self.auth).status_code, 404)
        self.assertEqual(self.client.post('/api/body-analyses/photo', headers=self.auth, json={'photo_id':huge}).status_code, 400)
        self.assertEqual(self.client.post('/api/ai-coach/messages', headers=self.auth, json={'content':'test','analysis_id':huge}).status_code, 422)
        for path in ('/api/photos', '/api/body-analyses'):
            self.assertEqual(self.client.get(path, headers=self.auth, params={'page':huge}).status_code, 400)

    def test_analysis_history_pages_keep_total_order_and_owner(self):
        with self.service.db() as db:
            for uid in (1, 2):
                for index in range(9):
                    db.execute('INSERT INTO analyses(uid,photo_id,status,created_at,payload) VALUES(?,?,?,?,?)',
                        (uid, index+1, 'done', '2026-11-05T00:00:00+00:00', '{"large":"unused"}'))
            identifiers = [row[0] for row in db.execute('SELECT id FROM analyses WHERE uid=1 ORDER BY id DESC')]
        body = self.client.get('/api/body-analyses', headers=self.auth, params={'page':2,'page_size':3}).json()
        self.assertEqual(body['total'], 9)
        self.assertEqual([item['analysis_id'] for item in body['items']], identifiers[3:6])
        empty = self.client.get('/api/body-analyses', headers=self.auth, params={'page':10,'page_size':3}).json()
        self.assertEqual(empty['items'], [])
        self.assertEqual(empty['total'], 9)

    def test_backend_base_url_cannot_include_credentials_path_or_query(self):
        for url in ('https://127.0.0.1', 'http://outside.example',
                    'http://user:password@127.0.0.1', 'http://127.0.0.1/path',
                    'http://127.0.0.1?url=outside', 'http://127.0.0.1#fragment'):
            with self.assertRaises(ValueError):
                FlutterBridge(self.temp.name, url, lambda:self.engine, save_image)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        app = FastAPI()
        self.engine = FakeEngine()
        app.state.engine = self.engine
        self.service = install(app, self.temp.name, 'http://127.0.0.1:8082', save_image)
        self.addCleanup(self.service.close)
        self.client = TestClient(app)
        self.addCleanup(self.client.close)
        self.auth = {'Authorization': 'Bearer alice'}
        self.mock = patch('bridge.api.requests.Session.request', side_effect=self.backend)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def backend(self, method, url, headers, **kwargs):
        token = headers.get('Authorization')
        uid = {'Bearer alice': 1, 'Bearer bob': 2}.get(token)
        if url.endswith('/api/users/me') and uid:
            body = {'user_id': uid, 'role': 'user', 'onboarding_completed': True,
                    'body_photo_agreed': True, 'ai_processing_agreed': True}
            return SimpleNamespace(status_code=200, json=lambda: body)
        return SimpleNamespace(status_code=401, json=lambda: {})

    def upload(self, headers=None):
        response = self.client.post('/api/photos', files={'image': image()},
            data={'type': 'current', 'side': 'front'}, headers=headers or self.auth)
        self.assertEqual(response.status_code, 201)
        return response.json()

    def finish(self, analysis_id):
        for _ in range(200):
            response = self.client.get(f'/api/body-analyses/{analysis_id}', headers=self.auth)
            if response.json()['status'] != 'pending':
                return response.json()
            time.sleep(.01)
        self.fail('fake analysis did not finish')

    def test_owned_side_photo_reaches_engine(self):
        front = self.upload()
        side = self.client.post('/api/photos', files={'image': image()},
            data={'type': 'current', 'side': 'side'}, headers=self.auth).json()
        response = self.client.post('/api/body-analyses/photo', json={
            'photo_id': front['photo_id'], 'side_photo_id': side['photo_id']}, headers=self.auth)
        self.assertEqual(response.status_code, 202)
        result = self.finish(response.json()['analysis_id'])
        self.assertEqual(result['status'], 'done')
        self.assertEqual(result['side_photo_id'], side['photo_id'])
        self.assertTrue(self.engine.last_kwargs['side_path'].is_file())

    def test_authentication_is_checked_in_spring_and_not_from_client_user_id(self):
        response = self.client.get('/api/body-analyses/usage')
        self.assertEqual(response.status_code, 401)
        response = self.client.get('/api/body-analyses/usage', headers={'Authorization': 'Bearer invalid'})
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()['code'], 'UNAUTHORIZED')

    def test_upload_signed_photo_async_result_cache_and_history(self):
        photo = self.upload()
        self.assertEqual(self.client.get(photo['url']).status_code, 200)
        self.assertEqual(self.client.get(photo['url']+'x').status_code, 404)
        response = self.client.post('/api/body-analyses/photo', json={'photo_id': photo['photo_id']}, headers=self.auth)
        self.assertEqual(response.status_code, 202)
        aid = response.json()['analysis_id']
        detail = self.finish(aid)
        self.assertEqual(detail['status'], 'done')
        self.assertEqual(detail['measures']['shoulder_tilt_deg'], .4)
        self.assertIsNone(detail['balance_score'])
        self.assertNotIn('debug_image_base64', detail)
        self.assertEqual(self.client.post('/api/body-analyses/photo', json={'photo_id': photo['photo_id']}, headers=self.auth).json()['analysis_id'], aid)
        self.assertEqual(self.engine.calls, 1)
        history = self.client.get('/api/body-analyses', headers=self.auth).json()
        self.assertEqual(history['items'][0]['analysis_id'], aid)

    def test_other_user_cannot_read_analyse_or_delete_photo(self):
        photo = self.upload()
        bob = {'Authorization': 'Bearer bob'}
        response = self.client.post('/api/body-analyses/photo', json={'photo_id': photo['photo_id']}, headers=bob)
        self.assertEqual(response.status_code, 404)
        self.assertEqual(self.client.delete('/api/photos/'+str(photo['photo_id']), headers=bob).status_code, 404)
        response = self.client.post('/api/body-analyses/photo', json={'photo_id': photo['photo_id']}, headers=self.auth)
        aid = response.json()['analysis_id']
        self.finish(aid)
        self.assertEqual(self.client.get('/api/body-analyses/'+str(aid), headers=bob).status_code, 404)

    def test_failure_does_not_spend_quota_and_delete_invalidates_url(self):
        self.engine.failure = True
        photo = self.upload()
        aid = self.client.post('/api/body-analyses/photo', json={'photo_id': photo['photo_id']}, headers=self.auth).json()['analysis_id']
        detail = self.finish(aid)
        self.assertEqual(detail['error_code'], 'IMAGE_BLURRY')
        self.assertEqual(self.client.get('/api/body-analyses/usage', headers=self.auth).json()['used'], 0)
        self.assertEqual(self.client.delete('/api/photos/'+str(photo['photo_id']), headers=self.auth).status_code, 204)
        self.assertEqual(self.client.get(photo['url']).status_code, 404)

    def test_invalid_image_and_unknown_ids_are_rejected(self):
        response = self.client.post('/api/photos', files={'image': ('bad.jpg', b'bad', 'image/jpeg')}, headers=self.auth)
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['code'], 'VALIDATION_FAILED')
        self.assertEqual(self.client.get('/api/body-analyses/999', headers=self.auth).status_code, 404)
        self.assertEqual(self.client.post('/api/body-analyses/photo', json={}, headers=self.auth).status_code, 400)

    def test_broken_auth_response_is_service_error(self):
        with patch('bridge.api.requests.Session.request', return_value=SimpleNamespace(status_code=200, json=lambda: [])):
            response = self.client.get('/api/body-analyses/usage', headers=self.auth)
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()['code'], 'AUTH_SERVER_UNAVAILABLE')

    def test_auth_server_outage_is_not_an_expired_session(self):
        for status in (302, 404, 429, 500, 503):
            with self.subTest(status=status), patch('bridge.api.requests.Session.request',
                    return_value=SimpleNamespace(status_code=status)):
                response = self.client.get('/api/body-analyses/usage', headers=self.auth)
                self.assertEqual(response.status_code, 503)
                self.assertEqual(response.json()['code'], 'AUTH_SERVER_UNAVAILABLE')

    def test_malformed_signed_links_are_not_server_errors(self):
        photo = self.upload()
        from urllib.parse import urlsplit, parse_qs
        url = urlsplit(photo['url'])
        expiry = parse_qs(url.query)['expires'][0]
        for signature in ('한'*64, 'é'*64, 'a'*63, 'a'*65, '0'*64):
            response = self.client.get(url.path, params={'expires': expiry, 'signature': signature})
            self.assertEqual(response.status_code, 404)
        self.assertEqual(self.client.get(photo['url']).status_code, 200)

    def test_daily_quota_enforced_for_regular_user(self):
        for _ in range(3):
            photo = self.upload()
            response = self.client.post('/api/body-analyses/photo', json={'photo_id': photo['photo_id']}, headers=self.auth)
            self.assertEqual(self.finish(response.json()['analysis_id'])['status'], 'done')
        photo = self.upload()
        response = self.client.post('/api/body-analyses/photo', json={'photo_id': photo['photo_id']}, headers=self.auth)
        self.assertEqual(response.status_code, 429)
        self.assertEqual(self.engine.calls, 3)

    def test_database_commit_failure_releases_worker_reservation(self):
        photo = self.upload()
        original = self.service.db
        @contextmanager
        def failed_commit():
            with original() as connection:
                yield connection
                raise RuntimeError('simulated failed commit')
        user = {'user_id': 1}
        with patch.object(self.service, 'db', failed_commit):
            with self.assertRaises(RuntimeError):
                self.service.start(user, photo['photo_id'])
        self.assertTrue(self.service.capacity.acquire(blocking=False))
        self.service.capacity.release()
        self.assertEqual(self.service.active_files, {})
        with original() as connection:
            self.assertEqual(connection.execute('SELECT COUNT(*) FROM analyses').fetchone()[0], 0)

    def test_timed_out_worker_keeps_both_source_files_until_it_finishes(self):
        front = self.upload()
        side = self.client.post('/api/photos', files={'image': image()},
            data={'type': 'current', 'side': 'side'}, headers=self.auth).json()
        entered, release = threading.Event(), threading.Event()
        original = self.engine.analyze
        def blocked(path, directory, **kwargs):
            entered.set()
            if not release.wait(5):
                raise RuntimeError('test worker was not released')
            return original(path, directory, **kwargs)
        with patch.object(self.engine, 'analyze', side_effect=blocked):
            ticket = self.client.post('/api/body-analyses/photo', json={
                'photo_id': front['photo_id'], 'side_photo_id': side['photo_id']}, headers=self.auth).json()
            try:
                self.assertTrue(entered.wait(2))
                with self.service.db() as db:
                    db.execute("UPDATE analyses SET created_at='2000-01-01T00:00:00+00:00' WHERE id=?", (ticket['analysis_id'],))
                result = self.client.get(f"/api/body-analyses/{ticket['analysis_id']}", headers=self.auth).json()
                self.assertEqual(result['error_code'], 'AI_TIMEOUT')
                for photo in (front, side):
                    self.assertEqual(self.client.delete(f"/api/photos/{photo['photo_id']}", headers=self.auth).status_code, 409)
                    self.assertEqual(self.client.get(photo['url']).status_code, 200)
            finally:
                release.set()
                self.service.close()
        self.assertEqual(self.service.active_files, {})
        result = self.client.get(f"/api/body-analyses/{ticket['analysis_id']}", headers=self.auth).json()
        self.assertEqual(result['status'], 'failed')
        self.assertIsNone(result['measures'])
        for photo in (front, side):
            self.assertEqual(self.client.delete(f"/api/photos/{photo['photo_id']}", headers=self.auth).status_code, 204)

    def test_rejected_worker_submission_cleans_up_its_file_lease(self):
        photo = self.upload()
        with patch.object(self.service.executor, 'submit', side_effect=RuntimeError('executor stopped')):
            ticket = self.service.start({'user_id': 1}, photo['photo_id'])
        self.assertEqual(self.service.active_files, {})
        self.assertTrue(self.service.capacity.acquire(blocking=False))
        self.service.capacity.release()
        self.assertEqual(self.finish(ticket['analysis_id'])['status'], 'failed')
        self.assertEqual(self.client.delete(f"/api/photos/{photo['photo_id']}", headers=self.auth).status_code, 204)

    def test_upload_commit_failure_does_not_leave_a_private_orphan_file(self):
        original = self.service.db
        @contextmanager
        def failed_commit():
            with original() as connection:
                yield connection
                raise RuntimeError('simulated failed photo commit')
        with patch.object(self.service, 'db', failed_commit), self.assertRaisesRegex(RuntimeError, 'photo commit'):
            self.client.post('/api/photos', files={'image': image()}, headers=self.auth)
        self.assertEqual(list(self.service.photos.iterdir()), [])
        with original() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM photos').fetchone()[0], 0)

    def test_timeout_does_not_overwrite_a_result_that_completed_after_the_read(self):
        import json
        with self.service.db() as db:
            aid = db.execute("INSERT INTO analyses(uid,photo_id,status,created_at) VALUES(1,1,'pending','2000-01-01T00:00:00+00:00')").lastrowid
            class CompletingConnection:
                def execute(inner, query, params=()):
                    if "error_code='AI_TIMEOUT'" in query:
                        db.execute("UPDATE analyses SET status='done',payload=? WHERE id=?",
                            (json.dumps({'measures': {'shoulder_tilt_deg': 0}}), aid))
                    return db.execute(query, params)
            result = self.service.detail(CompletingConnection(), 1, aid)
        self.assertEqual(result['status'], 'done')
        self.assertIsNone(result['error_code'])
        self.assertEqual(result['measures']['shoulder_tilt_deg'], 0)

    def test_delete_commit_failure_preserves_original_file_and_signed_url(self):
        photo = self.upload()
        original = self.service.db
        @contextmanager
        def failed_commit():
            with original() as connection:
                yield connection
                raise RuntimeError('simulated failed delete commit')
        with patch.object(self.service, 'db', failed_commit), self.assertRaisesRegex(RuntimeError, 'delete commit'):
            self.client.delete(f"/api/photos/{photo['photo_id']}", headers=self.auth)
        self.assertEqual(self.client.get(photo['url']).status_code, 200)
        self.assertEqual(len(list(self.service.photos.iterdir())), 1)

    def test_filesystem_delete_failure_blocks_access_and_allows_owner_retry(self):
        photo = self.upload()
        with patch('bridge.api.Path.unlink', side_effect=PermissionError('test file busy')):
            response = self.client.delete(f"/api/photos/{photo['photo_id']}", headers=self.auth)
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()['code'], 'PHOTO_DELETE_INCOMPLETE')
        self.assertEqual(self.client.get(photo['url']).status_code, 404)
        self.assertEqual(len(list(self.service.photos.iterdir())), 1)
        self.assertEqual(self.client.delete(f"/api/photos/{photo['photo_id']}", headers={'Authorization':'Bearer bob'}).status_code, 404)
        self.assertEqual(self.client.delete(f"/api/photos/{photo['photo_id']}", headers=self.auth).status_code, 204)
        self.assertEqual(list(self.service.photos.iterdir()), [])

    def test_revoked_processing_consent_does_not_prevent_authenticated_cleanup(self):
        photo = self.upload()
        with self.service.db() as db:
            db.execute("INSERT INTO coach_messages(uid,role,content,created_at,source) VALUES(1,'user','test',?,'user')", ('2026-11-04T00:00:00+00:00',))
        revoked = {'user_id': 1, 'onboarding_completed': False,
            'body_photo_agreed': False, 'ai_processing_agreed': False}
        response = SimpleNamespace(status_code=200, json=lambda: revoked)
        with patch('bridge.api.requests.Session.request', return_value=response):
            self.assertEqual(self.client.post('/api/photos', files={'image': image()}, headers=self.auth).status_code, 403)
            self.assertEqual(self.client.get('/api/ai-coach/messages', headers=self.auth).status_code, 403)
            self.assertEqual(self.client.delete(f"/api/photos/{photo['photo_id']}", headers=self.auth).status_code, 204)
            self.assertEqual(self.client.delete('/api/ai-coach/messages', headers=self.auth).json()['deleted'], 1)
        self.assertEqual(self.client.delete('/api/photos/999').status_code, 401)


if __name__ == '__main__':
    unittest.main()
