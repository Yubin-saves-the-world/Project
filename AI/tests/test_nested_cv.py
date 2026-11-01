import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from test_contour_training import fixture
from analyzers.contour_classifier import ContourClassifier
from analyzers.dinov3_features import upper_arm_box
from training.nested_cv import benchmark_nested, choose_regularization, metrics


class NestedCVTests(unittest.TestCase):
    def test_nested_folds_are_disjoint_and_live_artifact_unchanged(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            fixture(root)
            (root/'model.json').write_text('live-model-sentinel')
            before = (root/'annotations.json').read_bytes()
            report = benchmark_nested(root)
            for fold in report['folds']:
                outer_test = set(fold['held_out_subjects'])
                self.assertFalse(outer_test & set(fold['train_subjects']))
                for inner in fold['inner_folds']:
                    self.assertFalse(set(inner['train_subjects']) & set(inner['validation_subjects']))
                    self.assertFalse(outer_test & (set(inner['train_subjects']) | set(inner['validation_subjects'])))
            self.assertFalse(report['independent_test'])
            self.assertFalse(report['deployed_model_changed'])
            self.assertEqual((root/'model.json').read_text(), 'live-model-sentinel')
            self.assertEqual((root/'annotations.json').read_bytes(), before)
            ContourClassifier(root/'nested-candidate-model.json')

    def test_equal_inner_scores_keep_conservative_regularization(self):
        x = np.ones((4, 768))
        y = np.asarray(['clear', 'clear', 'medium', 'medium'])
        groups = np.asarray(['a', 'b', 'c', 'd'])
        with patch('training.nested_cv.f1_score', return_value=.5):
            selected, _, _ = choose_regularization(x, y, groups, ['clear', 'medium'])
        self.assertEqual(selected, 1.)

    def test_missing_class_after_subject_removal_is_rejected(self):
        with self.assertRaises(ValueError):
            choose_regularization(np.ones((2, 768)), np.asarray(['clear', 'medium']),
                                  np.asarray(['a', 'b']), ['clear', 'medium'])

    def test_abstention_never_counts_as_correct_accepted_prediction(self):
        result = metrics(np.asarray(['clear']), np.asarray(['clear']), np.asarray([.55]), ['clear', 'medium'])
        self.assertEqual(result['accuracy'], 1)
        self.assertEqual(result['accepted_coverage'], 0)
        self.assertIsNone(result['accepted_accuracy'])

    def test_malformed_upper_arm_landmarks_return_no_crop(self):
        for bad in ({}, {'x': None, 'y': .5, 'visibility': .9},
                    {'x': .5, 'y': .5, 'visibility': 1.1}, {'x': True, 'y': .5, 'visibility': .9}):
            self.assertIsNone(upper_arm_box({'left_shoulder': bad, 'left_elbow': bad}, 'left', 100, 100))
