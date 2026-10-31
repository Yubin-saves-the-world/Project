"""Compatibility checks for the unchanged Flutter photo/analysis contract."""
import io
from contextlib import contextmanager
from pathlib import Path
from types import SimpleNamespace
import tempfile
import time
import unittest
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

from app import save_image
from bridge.api import install
from integration import AnalysisFailure


class FakeEngine:
    failure = False
    calls = 0

    def analyze(self, path, directory):
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
        self.mock = patch('bridge.api.requests.request', side_effect=self.backend)
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
        with patch('bridge.api.requests.request', return_value=SimpleNamespace(status_code=200, json=lambda: [])):
            response = self.client.get('/api/body-analyses/usage', headers=self.auth)
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()['code'], 'AUTH_SERVER_UNAVAILABLE')

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
        with original() as connection:
            self.assertEqual(connection.execute('SELECT COUNT(*) FROM analyses').fetchone()[0], 0)


if __name__ == '__main__':
    unittest.main()
