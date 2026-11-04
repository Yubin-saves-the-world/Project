import io
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from PIL import Image
import app as api
from integration import AnalysisFailure
from goal_comparison import compare_measurements


def photo():
    stream = io.BytesIO()
    Image.new('RGB', (64, 96), 'white').save(stream, format='PNG')
    return ('photo.png', stream.getvalue(), 'image/png')


class GoalComparisonTests(unittest.TestCase):
    def test_deltas_and_missing_values_never_become_zero_or_priority(self):
        result = compare_measurements({'measures': {'shoulder_hip_ratio': 1.6, 'pelvis_tilt_deg': 0}},
                                      {'measures': {'shoulder_hip_ratio': 1.8, 'pelvis_tilt_deg': 0}})
        self.assertEqual(result['items'][0]['delta_current_minus_goal'], -.2)
        self.assertEqual(result['items'][3]['delta_current_minus_goal'], 0)
        self.assertIsNone(result['items'][-1]['delta_current_minus_goal'])
        self.assertEqual(result['items'][-1]['missing_inputs'], ['current', 'goal'])
        self.assertEqual(result['priority_parts'], [])
        self.assertEqual(result['status'], 'partial')
        for bad in (True, float('nan'), float('inf')):
            self.assertEqual(compare_measurements({'measures': {'shoulder_hip_ratio': bad}},
                                                 {'measures': {'shoulder_hip_ratio': 1}})['compared_count'], 0)

    def test_endpoint_requires_confirmation_and_cleans_all_inputs(self):
        paths = []
        def analyze(path, output, *, side_path):
            self.assertTrue(path.is_file())
            if side_path:
                self.assertTrue(side_path.is_file())
                paths.append(side_path)
            paths.append(path)
            return {'status': 'done', 'measures': {'shoulder_hip_ratio': 1.5},
                    'debug_image_base64': 'private', 'dinov3': {'parts': ['private']}}
        engine = SimpleNamespace(analyze=analyze)
        with patch.object(api.app.state, 'engine', engine, create=True):
            client = TestClient(api.app, raise_server_exceptions=False)
            self.addCleanup(client.close)
            files = {'current_front': photo(), 'goal_front': photo(), 'current_side': photo()}
            response = client.post('/v1/compare', files=files)
            self.assertEqual(response.status_code, 422)
            self.assertEqual(response.json()['detail']['code'], 'PHOTO_CONDITIONS_UNCONFIRMED')
            self.assertEqual(paths, [])
            response = client.post('/v1/compare', files=files, data={'capture_conditions_confirmed': 'true'})
            self.assertEqual(response.status_code, 200)
            body = response.json()
            self.assertEqual(body['goal_comparison']['compared_count'], 1)
            self.assertNotIn('debug_image_base64', body['current'])
            self.assertNotIn('dinov3', body['goal'])
            self.assertEqual(len(paths), 3)
            self.assertTrue(all(not p.exists() for p in paths))

    def test_http_upload_validation_and_input_error(self):
        calls = []
        def analyze(path, output, **kwargs):
            calls.append(path)
            if len(calls) == 2:
                raise AnalysisFailure('NOT_FULL_BODY', '전신이 필요합니다.')
            return {'status': 'done', 'measures': {}}
        with patch.object(api.app.state, 'engine', SimpleNamespace(analyze=analyze), create=True):
            client = TestClient(api.app, raise_server_exceptions=False)
            self.addCleanup(client.close)
            valid = {'capture_conditions_confirmed': 'true'}
            response = client.post('/v1/compare', files={'current_front': photo(),
                'goal_front': ('bad.jpg', b'invalid', 'image/jpeg')}, data=valid)
            self.assertEqual(response.status_code, 422)
            self.assertEqual(calls, [])
            response = client.post('/v1/compare', files={'current_front': photo(), 'goal_front': photo()}, data=valid)
            self.assertEqual(response.status_code, 422)
            self.assertEqual(response.json()['detail']['input'], 'goal')
            self.assertTrue(all(not p.exists() for p in calls))
