import tempfile
import unittest
from pathlib import Path
from training.dataset import write_json
from training.readiness import readiness


class ReadinessTests(unittest.TestCase):
    def test_missing_labels_remain_missing_and_subjects_not_regions(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            write_json(root/'dataset.json', {'entries': [{'id': 'a'}, {'id': 'b'}, {'id': 'c'}, {'id': 'd'}]})
            write_json(root/'annotations.json', {
                'a': {'reviewed': True, 'label': 'clear', 'subject_id': 'one', 'split': 'train'},
                'b': {'reviewed': True, 'label': 'clear', 'subject_id': 'one', 'split': 'train'},
                'c': {'reviewed': True, 'label': 'exclude', 'subject_id': 'two', 'split': 'train', 'reason': 'covered'}})
            report = readiness(root)
            self.assertEqual(report['usable_regions'], 2)
            self.assertEqual(report['distinct_subjects'], 1)
            self.assertEqual(report['excluded'], 1)
            self.assertEqual(report['pending'], 1)
            self.assertTrue(report['weak_class_missing'])
            self.assertFalse(report['grouped_cv_minimum_counts_met'])
            self.assertFalse(report['holdout_minimum_counts_met'])

    def test_invalid_reviewed_annotation_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            write_json(root/'dataset.json', {'entries': [{'id': 'a'}]})
            write_json(root/'annotations.json', {'a': {'reviewed': True, 'label': 'made_up'}})
            with self.assertRaises(ValueError):
                readiness(root)
