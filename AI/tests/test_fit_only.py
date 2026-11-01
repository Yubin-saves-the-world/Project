"""Synthetic code-path checks; never used as actual training data."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import numpy as np

from test_contour_training import fixture
from training.fit_only import fit_only
from training.dataset import write_json
from training.train import read_training_data
from analyzers.contour_classifier import ContourClassifier


class FitOnlyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.entries, self.annotations = fixture(self.source)
        self.output = self.root / 'new-model'

    def test_export_is_explicitly_unvalidated_and_preserves_source(self):
        before = (self.source/'annotations.json').read_bytes()
        report = fit_only(self.source, self.output)
        self.assertEqual(report['samples'], 12)
        self.assertIsNone(report['evaluation'])
        self.assertFalse(report['independent_test'])
        self.assertEqual(report['consumed_splits'], {'train': 6, 'val': 3, 'test': 3})
        classifier = ContourClassifier(self.output/'model.json')
        vector = np.load(self.source/'features/weak-0.npz')['vector']
        prediction = classifier.predict(vector)
        self.assertEqual(prediction['validation_status'], 'not_evaluated')
        self.assertEqual(set(prediction['probabilities']), {'weak','medium','clear'})
        self.assertEqual((self.source/'annotations.json').read_bytes(), before)
        with self.assertRaisesRegex(ValueError, '덮어쓰지'):
            fit_only(self.source, self.output)

    def test_pending_labels_are_not_silently_dropped(self):
        del self.annotations['weak-0']
        write_json(self.source/'annotations.json', self.annotations)
        with self.assertRaisesRegex(ValueError, '검수 저장'):
            fit_only(self.source, self.output)
        self.assertFalse(self.output.exists())

    def test_label_edit_during_fit_does_not_publish_model(self):
        from training import fit_only as module
        original = module.LogisticRegression.fit
        def editing(model, *args, **kwargs):
            result = original(model, *args, **kwargs)
            write_json(self.source/'annotations.json', {})
            return result
        with patch.object(module.LogisticRegression, 'fit', editing):
            with self.assertRaisesRegex(ValueError, '변경'):
                fit_only(self.source, self.output)
        self.assertFalse(self.output.exists())

    def test_inherited_review_proof_is_checked_before_training(self):
        # A merge retains entry proofs without a top-level release marker.
        self.entries[0]['review_hashes'] = {'image': 'wrong', 'crop': 'wrong'}
        write_json(self.source/'dataset.json', {'entries': self.entries})
        (self.source/'fake.jpg').write_bytes(b'changed after review')
        with self.assertRaisesRegex(ValueError, '해시'):
            read_training_data(self.source, enforce_holdout=False)
