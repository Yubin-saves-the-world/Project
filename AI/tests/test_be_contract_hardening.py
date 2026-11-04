import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import cv2
import numpy as np
from fastapi.testclient import TestClient

import app as api
from integration import AnalysisEngine, public_measurement_reason
from test_api_contract import photo


class BackendContractTests(unittest.TestCase):
    def test_explicit_geometry_mode_never_attempts_gated_model(self):
        with patch.dict(os.environ,{'AI_DISABLE_DINO':'1','AI_REQUIRE_DINO':'0'}), \
             patch('integration.DinoFeatureExtractor') as dino:
            engine=AnalysisEngine('gated-repository',pose_guard=False)
        self.assertIsNone(engine.dino)
        dino.assert_not_called()

    def test_missing_dino_still_returns_geometry_and_contract_judgements(self):
        with patch.dict(os.environ, {'AI_REQUIRE_DINO':'0'}), patch(
                'integration.DinoFeatureExtractor', side_effect=FileNotFoundError('missing')):
            engine=AnalysisEngine('missing',pose_guard=False)
        self.assertIsNone(engine.dino)
        points={k:{'x':x,'y':y,'visibility':.9} for k,x,y in [
            ('nose',.5,.1),('left_shoulder',.3,.3),('right_shoulder',.7,.3),
            ('left_hip',.4,.6),('right_hip',.6,.6),('left_ankle',.4,.9),('right_ankle',.6,.9)]}
        result={'landmarks':points,'metrics':{'shoulder_tilt_deg':1.,'hip_tilt_deg':2.,
            'shoulder_to_hip_ratio':1.5,'torso_leg_ratio':.7}}
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);image=p/'front.jpg'
            cv2.imwrite(str(image),np.random.default_rng(42).integers(0,256,(300,200,3),dtype=np.uint8))
            with patch('integration.analyze_image',return_value=(None,None,result)),patch('integration.draw_overlay',return_value=b'jpeg'):
                response=engine.analyze(image,p,include_review_previews=True)
        self.assertEqual(response['status'],'done')
        self.assertIsNone(response['dinov3'])
        self.assertEqual(response['measures']['shoulder_tilt_deg'],1.)
        self.assertEqual(response['measures']['unavailable'],[{'key':'neck_forward_deg','reason':'SIDE_PHOTO_MISSING'}])
        self.assertLessEqual(len(response['measurement_version']),20)
        for item in response['judgements']:
            self.assertIsInstance(item['label'],str)
            self.assertTrue(item['label'])
            self.assertIn(item['unit'],['deg','ratio'])

    def test_required_dino_still_fails_startup(self):
        with patch.dict(os.environ,{'AI_REQUIRE_DINO':'1'}),patch(
                'integration.DinoFeatureExtractor',side_effect=FileNotFoundError):
            with self.assertRaises(FileNotFoundError):AnalysisEngine('missing',pose_guard=False)

    def test_degraded_health_and_contour_guard(self):
        engine=SimpleNamespace(dino=None,contour=object(),pose_guard=None)
        with patch.object(api.app.state,'engine',engine,create=True):
            client=TestClient(api.app)
            self.addCleanup(client.close)
            response=client.get('/health').json()
            self.assertEqual(response['status'],'degraded')
            self.assertFalse(response['dinov3_loaded'])
            self.assertFalse(response['capabilities']['multiple_people_check'])
            response=client.post('/v1/contour/classify',files={'image':photo()},
                                 data={'skin_visible_confirmed':'true'})
            self.assertEqual(response.status_code,503)
            self.assertEqual(response.json()['detail']['code'],'MODEL_NOT_CONFIGURED')

    def test_reason_mapping_uses_backend_vocabulary(self):
        self.assertEqual(public_measurement_reason('SIDE_PHOTO_REQUIRED'),'SIDE_PHOTO_MISSING')
        for reason in ['SIDE_NO_PERSON','INVALID_SIDE_IMAGE','SIDE_VIEW_UNCONFIRMED']:
            self.assertEqual(public_measurement_reason(reason),'LOW_CONFIDENCE')

    def test_validation_error_has_safe_object_detail(self):
        client=TestClient(api.app)
        self.addCleanup(client.close)
        for route in ['/v1/analyze','/v1/compare','/v1/contour/classify']:
            response=client.post(route)
            self.assertEqual(response.status_code,422)
            detail=response.json()['detail']
            self.assertEqual(detail['code'],'VALIDATION_FAILED')
            self.assertLessEqual(len(detail['message']),100)
