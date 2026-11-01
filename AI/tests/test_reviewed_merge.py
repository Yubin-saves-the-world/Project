from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image
from test_contour_training import fixture
from scripts import merge_reviewed_datasets as merging
from training.dataset import AnnotationStore, write_json


class ReviewedMergeTests(unittest.TestCase):
    def test_changed_reviewed_image_cannot_enter_merged_dataset(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            source = root/'.runtime/kaggle_batch'
            source.mkdir(parents=True)
            entries, _ = fixture(source)
            Image.new('RGB', (8, 8), 'white').save(source/'fake.jpg')
            entries[0]['review_hashes'] = {'image': 'wrong', 'crop': 'wrong'}
            write_json(source/'dataset.json', {'entries': entries})
            with patch.object(merging, 'ROOT', root):
                with self.assertRaisesRegex(ValueError, '해시'):
                    merging.merge(root/'.runtime/combined', {'kaggle':'kaggle_batch'})
            self.assertFalse((root/'.runtime/combined').exists())

    def test_explicit_new_dataset_preserves_labels_and_namespaces_people(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            source = root/'.runtime/kaggle_batch'
            source.mkdir(parents=True)
            fixture(source)
            Image.new('RGB', (8, 8), 'white').save(source/'fake.jpg')
            before = (source/'annotations.json').read_bytes()
            with patch.object(merging, 'ROOT', root):
                count = merging.merge(root/'.runtime/combined', {'kaggle': 'kaggle_batch'})
            store = AnnotationStore(root/'.runtime/combined')
            self.assertEqual(count, len(store.entries))
            self.assertTrue(all(a['subject_id'].startswith('kaggle_') for a in store.annotations.values()))
            self.assertEqual((source/'annotations.json').read_bytes(), before)

    def test_unlabeled_dataset_and_path_escape_are_rejected_without_output(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            source = root/'.runtime/kaggle_batch';source.mkdir(parents=True)
            fixture(source)
            write_json(source/'annotations.json', {})
            with patch.object(merging, 'ROOT', root):
                for names in ({'kaggle': 'kaggle_batch'}, {'../bad': 'kaggle_batch'},
                              {'old': 'quarantine_web_test'}, {'outside': str(root/'outside')}):
                    with self.assertRaises((ValueError, FileNotFoundError)):
                        merging.merge(root/'.runtime/combined', names)
                    self.assertFalse((root/'.runtime/combined').exists())
