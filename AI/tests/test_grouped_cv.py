import json
from pathlib import Path
import tempfile
import unittest
from test_contour_training import fixture
from training.grouped_cv import train_grouped_cv
from analyzers.contour_classifier import ContourClassifier

class GroupedCVTests(unittest.TestCase):
    def test_subjects_are_disjoint_and_final_artifact_is_loadable(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory);fixture(p)
            before=(p/'annotations.json').read_bytes()
            report=train_grouped_cv(p)
            plan=json.loads((p/'cv-plan.json').read_text())
            for fold in plan['folds']:
                self.assertFalse(set(fold['train_subjects']) & set(fold['held_out_subjects']))
            self.assertFalse(report['independent_test'])
            self.assertEqual((p/'annotations.json').read_bytes(),before)
            ContourClassifier(p/'model.json')

    def test_validation_does_not_create_model(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory);fixture(p)
            report=train_grouped_cv(p,validate_only=True)
            self.assertEqual(report['subjects'],12)
            self.assertFalse((p/'model.json').exists())
