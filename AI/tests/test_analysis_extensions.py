import tempfile
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import cv2
import numpy as np
from integration import AnalysisEngine, AnalysisFailure, valid_landmark
from measurement_report import measurement_report


class AnalysisExtensionsTests(unittest.TestCase):
    def make_engine(self, guard=False):
        with patch('integration.DinoFeatureExtractor'):
            return AnalysisEngine('unused', pose_guard=guard)

    def test_multiple_people_rejected_before_feature_extraction(self):
        guard = SimpleNamespace(inspect=lambda rgb: {'status': 'checked', 'multiple_people_detected': True})
        engine = self.make_engine(guard)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'photo.jpg'
            cv2.imwrite(str(path), np.random.default_rng(42).integers(0, 256, (300, 200, 3), dtype=np.uint8))
            with patch('integration.analyze_image') as legacy:
                with self.assertRaises(AnalysisFailure) as failure:
                    engine.analyze(path, Path(directory))
                self.assertEqual(failure.exception.code, 'MULTIPLE_PEOPLE')
                legacy.assert_not_called()
                engine.dino.extract.assert_not_called()

    def test_side_no_pose_is_explicit_partial_result(self):
        engine = self.make_engine()
        image = np.zeros((100, 100, 3), dtype=np.uint8)
        with patch('integration.cv2.imread', return_value=image), patch('integration.analyze_image', side_effect=RuntimeError('No body pose')):
            result = engine._side_measure('side.jpg', Path('/tmp'))
        self.assertEqual(result['reason'], 'SIDE_NO_PERSON')
        self.assertIsNone(result['value'])
        self.assertEqual(engine._side_measure(None, Path('/tmp'))['reason'], 'SIDE_PHOTO_REQUIRED')

    def test_measured_side_angle_is_reported_without_health_judgement(self):
        report = measurement_report({'neck_forward_deg': 9.25}, [])
        item = next(i for i in report['items'] if i['key'] == 'neck_forward_deg')
        self.assertEqual(item['status'], 'measured')
        self.assertEqual(item['display_value'], '9.25°')
        self.assertIn('귀·어깨', item['title'])
        self.assertIn('판정하지', item['limitation'])

    def test_visibility_must_be_finite_numeric_and_bounded(self):
        for visibility in (True, 1.1, float('nan'), None, -.1):
            self.assertFalse(valid_landmark({'x': .5, 'y': .5, 'visibility': visibility}))
        self.assertTrue(valid_landmark({'x': .5, 'y': .5, 'visibility': .9}))
