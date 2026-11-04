"""HTTP boundary checks without downloading a model or accessing other teams' code."""
import io
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient
from PIL import Image

import app as api
from integration import AnalysisFailure
from schemas.analysis_result import BodyAnalysisResponse


def photo():
    stream = io.BytesIO()
    Image.new('RGB', (32, 48), 'white').save(stream, format='PNG')
    return ('front.png', stream.getvalue(), 'image/png')


class FakeEngine:
    dino = SimpleNamespace(device='cpu')

    def analyze(self, path, root):
        self.path = path
        assert Path(path).is_file()
        return {'status': 'done', 'measurement_version': 'pixel-dino-v1',
                'measures': {'shoulder_tilt_deg': .5}, 'balance_score': None}


class ApiContractTests(unittest.TestCase):
    def setUp(self):
        self.engine = FakeEngine()
        engine_patch = patch.object(api.app.state, 'engine', self.engine, create=True)
        engine_patch.start()
        self.addCleanup(engine_patch.stop)
        self.client = TestClient(api.app, raise_server_exceptions=False)
        self.addCleanup(self.client.close)

    def test_zip_photo_test_page_is_served(self):
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('MOVID', response.text)
        self.assertIn('/v1/analyze', response.text)

    def test_v1_response_and_temporary_file_cleanup(self):
        response = self.client.post('/v1/analyze', files={'front_images': photo()})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['measurement_version'], 'pixel-dino-v1')
        self.assertIsNone(response.json()['balance_score'])
        self.assertFalse(self.engine.path.exists())

    def test_legacy_keeps_camel_case_schema_and_text(self):
        legacy = BodyAnalysisResponse(posture={}, bodyShape={'bodyType': 'unknown'},
            judgements=[], priorityParts=[], comparisonSummary='', comparisonDetail='')
        with patch('app.analyze_body_images', return_value=legacy) as pipeline:
            response = self.client.post('/analyze/body', files=[('front_images', photo()),
                ('front_images', photo())], data={'text': '기존 요청'})
        self.assertEqual(response.status_code, 200)
        self.assertIn('bodyShape', response.json())
        self.assertIn('measurementVersion', response.json())
        self.assertNotIn('measurement_version', response.json())
        self.assertEqual(pipeline.call_args.kwargs['text_input'], '기존 요청')
        self.assertEqual(len(pipeline.call_args.args[0]), 2)
        self.assertFalse(Path(pipeline.call_args.args[1]).exists())

    def test_missing_and_multiple_v1_photos_rejected(self):
        self.assertEqual(self.client.post('/v1/analyze').status_code, 422)
        response = self.client.post('/v1/analyze', files=[('front_images', photo())] * 2)
        self.assertEqual(response.status_code, 422)

    def test_invalid_image_rejected_and_slot_released(self):
        response = self.client.post('/v1/analyze', files={'front_images': ('bad.jpg', b'bad', 'image/jpeg')})
        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()['detail']['code'], 'INVALID_IMAGE')
        self.assertEqual(self.client.post('/v1/analyze', files={'front_images': photo()}).status_code, 200)

    def test_oversized_upload_rejected(self):
        response = self.client.post('/v1/analyze', files={'front_images': ('large.jpg', b'x' * (api.MAX_BYTES + 1), 'image/jpeg')})
        self.assertEqual(response.status_code, 413)

    def test_both_routes_share_busy_limit(self):
        self.assertTrue(api.capacity.acquire(blocking=False))
        try:
            for route in ('/v1/analyze', '/analyze/body'):
                response = self.client.post(route, files={'front_images': photo()})
                self.assertEqual(response.status_code, 503)
                self.assertEqual(response.json()['detail']['code'], 'AI_BUSY')
        finally:
            api.capacity.release()

    def test_domain_failure_retains_code_and_cleans_up(self):
        paths = []
        def fail(path, root):
            paths.append(path)
            raise AnalysisFailure('NO_PERSON', '전신 사진을 사용해 주세요.')
        with patch.object(self.engine, 'analyze', side_effect=fail):
            response = self.client.post('/v1/analyze', files={'front_images': photo()})
        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()['detail']['code'], 'NO_PERSON')
        self.assertFalse(paths[0].exists())


if __name__ == '__main__':
    unittest.main()
