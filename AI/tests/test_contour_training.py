"""Synthetic fixtures test code paths only; they are never deployed as trained models."""
import json
import os
from types import SimpleNamespace
from unittest.mock import patch
from PIL import Image
from pathlib import Path
import tempfile
import unittest

import numpy as np
from fastapi.testclient import TestClient

from analyzers.contour_classifier import ContourClassifier
from analyzers.dinov3_features import MODEL_REVISION
from training.dataset import AnnotationStore, SCHEMA, local_api, write_json
from training.label_server import create_app
from training.train import read_training_data, train


def fixture(directory, labels=('weak', 'medium', 'clear')):
    root = Path(directory)
    (root / 'features').mkdir()
    entries, annotations = [], {}
    rng = np.random.default_rng(42)
    for category, label in enumerate(labels):
        for index, split in enumerate(('train', 'train', 'val', 'test')):
            key = f'{label}-{index}'
            vector = rng.normal(0, .01, 768)
            vector[category] = 1
            np.savez_compressed(root / 'features' / (key + '.npz'), vector=vector)
            entries.append({'id': key, 'features': 'features/' + key + '.npz', 'image': 'fake.jpg', 'crop': 'fake.jpg',
                            'image_name': 'SYNTHETIC', 'source_sha256': key, 'part': 'left_upper_arm',
                            'feature_schema': SCHEMA, 'model_revision': MODEL_REVISION})
            annotations[key] = {'subject_id': key, 'label': label, 'split': split, 'reviewed': True, 'reason': ''}
    write_json(root / 'dataset.json', {'schema_version': 1, 'entries': entries})
    write_json(root / 'annotations.json', annotations)
    return entries, annotations


class TrainingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.entries, self.annotations = fixture(self.root)

    def test_exported_multiclass_json_matches_sklearn_probabilities(self):
        artifact, report, reference = train(self.root)
        classifier = ContourClassifier(self.root / 'model.json')
        groups, _, _ = read_training_data(self.root)
        for vector, _, _ in groups['test']:
            prediction = classifier.predict(vector)
            expected = reference.predict_proba([vector])[0]
            np.testing.assert_allclose(list(prediction['probabilities'].values()), expected, atol=1e-5)
        self.assertFalse(report['test_used_for_training_or_selection'])
        self.assertEqual(artifact['task'], 'upper_arm_contour_visibility')
        self.assertIn('accepted_coverage', report['evaluation']['test'])

    def test_changing_test_labels_does_not_change_selected_model(self):
        artifact, first, _ = train(self.root)
        self.annotations['weak-3']['label'] = 'clear'
        self.annotations['clear-3']['label'] = 'weak'
        write_json(self.root / 'annotations.json', self.annotations)
        changed, second, _ = train(self.root)
        self.assertEqual(first['selected_C'], second['selected_C'])
        np.testing.assert_allclose(artifact['coefficients'], changed['coefficients'])
        self.assertNotEqual(first['evaluation']['test']['accuracy'], second['evaluation']['test']['accuracy'])

    def test_same_subject_in_train_and_test_is_rejected(self):
        self.annotations['weak-3']['subject_id'] = 'weak-0'
        write_json(self.root / 'annotations.json', self.annotations)
        with self.assertRaisesRegex(ValueError, '동일 인물'):
            read_training_data(self.root)

    def test_same_source_image_with_different_subject_is_rejected(self):
        self.entries[3]['source_sha256'] = self.entries[0]['source_sha256']
        write_json(self.root / 'dataset.json', {'entries': self.entries})
        with self.assertRaisesRegex(ValueError, '인물 ID'):
            read_training_data(self.root)

    def test_identical_features_across_split_are_rejected(self):
        (self.root / self.entries[3]['features']).write_bytes((self.root / self.entries[0]['features']).read_bytes())
        with self.assertRaisesRegex(ValueError, '동일 특징'):
            read_training_data(self.root)

    def test_unreviewed_data_cannot_train(self):
        write_json(self.root / 'annotations.json', {})
        with self.assertRaisesRegex(ValueError, '검수한 라벨'):
            train(self.root)
        self.assertFalse((self.root / 'model.json').exists())

    def test_too_few_training_subjects_is_rejected(self):
        self.annotations['weak-1']['reviewed'] = False
        write_json(self.root / 'annotations.json', self.annotations)
        with self.assertRaisesRegex(ValueError, '최소 2명'):
            read_training_data(self.root)

    def test_mismatched_revision_is_rejected(self):
        self.entries[0]['model_revision'] = 'different'
        write_json(self.root / 'dataset.json', {'entries': self.entries})
        with self.assertRaisesRegex(ValueError, '리비전'):
            read_training_data(self.root)

    def test_invalid_json_model_coefficients_and_feature_size_are_rejected(self):
        artifact, _, _ = train(self.root)
        artifact['coefficients'][0][0] = float('nan')
        (self.root / 'bad.json').write_text(json.dumps(artifact))
        with self.assertRaisesRegex(ValueError, '유한'):
            ContourClassifier(self.root / 'bad.json')
        classifier = ContourClassifier(self.root / 'model.json')
        with self.assertRaises(ValueError):
            classifier.predict(np.ones(10))

    def test_binary_json_matches_sklearn(self):
        with tempfile.TemporaryDirectory() as root:
            fixture(root, ('weak', 'clear'))
            _, _, reference = train(root)
            classifier = ContourClassifier(Path(root) / 'model.json')
            groups, _, _ = read_training_data(root)
            vector = groups['test'][0][0]
            np.testing.assert_allclose(list(classifier.predict(vector)['probabilities'].values()),
                                       reference.predict_proba([vector])[0], atol=1e-5)

    def test_label_api_persists_manual_review_and_blocks_cross_origin(self):
        write_json(self.root / 'annotations.json', {})
        with TestClient(create_app(self.root, 8002), base_url='http://127.0.0.1:8002') as client:
            self.assertEqual(client.get('/').status_code, 200)
            self.assertEqual(client.get('/api/entries').json()['reviewed'], 0)
            body = {'subject_id': 'person01', 'label': 'weak', 'split': 'train'}
            r = client.post('/api/annotations/weak-0', json=body, headers={'Origin': 'https://outside.example'})
            self.assertEqual(r.status_code, 403)
            r = client.post('/api/annotations/weak-0', json=body)
            self.assertEqual(r.status_code, 200)
            self.assertEqual(client.get('/api/entries').json()['reviewed'], 1)
            self.assertTrue(AnnotationStore(self.root).annotations['weak-0']['reviewed'])
            self.assertEqual(client.get('/asset/features/weak-0').status_code, 404)
            self.assertEqual(client.get('/', headers={'Host': 'outside.example'}).status_code, 403)

    def test_asset_path_cannot_escape_dataset(self):
        self.entries[0]['image'] = '../secret.jpg'
        write_json(self.root / 'dataset.json', {'entries': self.entries})
        with self.assertRaises(ValueError):
            AnnotationStore(self.root).asset('weak-0', 'image')

    def test_annotation_rejects_different_split_and_missing_exclusion_reason(self):
        store = AnnotationStore(self.root)
        with self.assertRaisesRegex(ValueError, '같은 train'):
            store.save('clear-3', 'weak-0', 'clear', 'test')
        with self.assertRaisesRegex(ValueError, '제외'):
            store.save('clear-3', 'new-person', 'exclude', 'test', '')

    def test_engine_uses_only_explicit_classifier_and_default_stays_untrained(self):
        from integration import AnalysisEngine
        train(self.root)
        vector = np.load(self.root / 'features/weak-0.npz')['vector']
        image = self.root / 'input.jpg'
        Image.fromarray(np.random.default_rng(4).integers(0, 256, (400, 200, 3), dtype=np.uint8)).save(image)
        dino = SimpleNamespace(revision=MODEL_REVISION, device='cpu', extract=lambda image: (
            {'cls': vector[:384], 'patch_mean': vector[384:], 'patches': np.zeros((196, 384))}, .01))
        positions = {'nose': (.5, .1), 'left_shoulder': (.3, .2), 'right_shoulder': (.7, .2),
                     'left_elbow': (.3, .5), 'right_elbow': (.7, .5), 'left_hip': (.35, .6),
                     'right_hip': (.65, .6), 'left_ankle': (.35, .95), 'right_ankle': (.65, .95)}
        output = {'landmarks': {key: {'x': xy[0], 'y': xy[1], 'visibility': .99} for key, xy in positions.items()},
                  'metrics': {'shoulder_tilt_deg': .4, 'hip_tilt_deg': .5,
                              'shoulder_to_hip_ratio': 1.7, 'torso_leg_ratio': .7}}
        with patch('integration.DinoFeatureExtractor', return_value=dino), \
             patch('integration.analyze_image', return_value=(None, str(image), output)):
            with patch.dict(os.environ, {'AI_CONTOUR_MODEL': str(self.root / 'model.json')}):
                result = AnalysisEngine('unused').analyze(image, self.root)
                self.assertTrue(result['dinov3']['parts'][0]['contour']['experimental'])
            with patch.dict(os.environ, {}, clear=True):
                result = AnalysisEngine('unused').analyze(image, self.root)
                self.assertEqual(result['dinov3']['parts'][0]['classification'], 'not_trained')
                self.assertNotIn('contour', result['dinov3']['parts'][0])

    def test_external_photo_api_is_rejected(self):
        with self.assertRaises(ValueError):
            local_api('https://outside.example')
        self.assertEqual(local_api('http://127.0.0.1:8001/'), 'http://127.0.0.1:8001')


if __name__ == '__main__':
    unittest.main()
