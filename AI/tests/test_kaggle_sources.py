import io
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from training.kaggle_sources import archive_inventory, download_archive, safe_member, usage_summary, make_review_queue, inspect_tables
from training.dataset import write_json


class KaggleSourceTests(unittest.TestCase):
    def test_traversal_and_windows_paths_are_rejected(self):
        for name in ('../secret', '/root/file', 'C:\\secret', 'safe/../../file', 'safe\\..\\..\\secret'):
            with self.assertRaises(ValueError):
                safe_member(name)
        self.assertEqual(str(safe_member('somaset/01/01/0001.jpg')), 'somaset/01/01/0001.jpg')

    def test_inventory_does_not_extract_or_approve_photos(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'data.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                archive.writestr('original.jpg', b'not displayed')
                archive.writestr('data.csv', 'age,height\n25,170\n')
            inventory = archive_inventory(path)
            self.assertEqual(inventory['files'], 2)
            self.assertEqual(inventory['extensions'], {'.jpg': 1, '.csv': 1})
            self.assertFalse((path.parent/'original.jpg').exists())

    def test_symlinks_and_archive_bombs_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'data.zip'
            with zipfile.ZipFile(path, 'w') as archive:
                item = zipfile.ZipInfo('link')
                item.external_attr = (stat.S_IFLNK | 0o777) << 16
                archive.writestr(item, 'target')
            with self.assertRaises(ValueError):
                archive_inventory(path)

    def test_html_response_never_becomes_a_dataset_archive(self):
        response = io.BytesIO(b'<html>Sign in</html>')
        response.headers = {}
        with tempfile.TemporaryDirectory() as folder, patch('training.kaggle_sources.open_url', return_value=response):
            path = Path(folder)/'download.zip'
            with self.assertRaisesRegex(ValueError, 'non-ZIP'):
                download_archive('https://www.kaggle.com/example', path)
            self.assertFalse(path.exists())
            self.assertFalse(path.with_suffix('.part').exists())

    def test_interrupted_download_does_not_replace_existing_archive(self):
        response = io.BytesIO(b'broken')
        response.headers = {'Content-Length': '100'}
        with tempfile.TemporaryDirectory() as folder, patch('training.kaggle_sources.open_url', return_value=response):
            path = Path(folder)/'download.zip';path.write_bytes(b'old intact archive')
            with self.assertRaisesRegex(ValueError, 'Incomplete'):
                download_archive('https://www.kaggle.com/example', path)
            self.assertEqual(path.read_bytes(), b'old intact archive')


class KaggleQueueTests(unittest.TestCase):
    def test_public_samples_and_synthetic_avatars_are_not_counted_as_training_labels(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for key, names in (
                ('body_measurements', ['1/front_img.jpg', '1/side_img.jpg', '2/front_img.jpg']),
                ('somaset', ['somaset/01/01/0001.jpg', 'somaset/01/02/0001.jpg'])):
                write_json(root/key/'source.json', {'status': 'downloaded_unreviewed', 'archive': {'sha256': 'knownhash'}})
                write_json(root/key/'inventory.json', {'members': [{'name': n} for n in names]})
            report = usage_summary(root)
            sources = {s['key']: s for s in report['sources']}
            self.assertEqual(sources['body_measurements']['known_source_identities'], 2)
            self.assertEqual(sources['somaset']['known_source_identities'], 1)
            self.assertEqual(sources['somaset']['identity_kind'], 'synthetic_avatar')
            self.assertFalse(report['ready_for_contour_training'])
            queue = make_review_queue(root)
            self.assertEqual(len(queue), 4)
            self.assertTrue(all(row['human_contour_label'] is None for row in queue))
            self.assertTrue(all(row['review_status'] == 'not_reviewed' for row in queue))
            self.assertFalse((root/'dataset.json').exists())
            self.assertNotEqual(queue[0]['subject_hint'], queue[-1]['subject_hint'])

    def test_missing_source_is_queued_and_partial_download_is_not_ready(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'somaset').mkdir()
            (root/'somaset/download.part').write_bytes(b'partial')
            rows = {r['key']: r for r in usage_summary(root)['sources']}
            self.assertEqual(rows['somaset']['status'], 'downloading')
            self.assertEqual(rows['somaset']['in_progress_bytes'], 7)
            self.assertEqual(rows['body_fat']['status'], 'queued')


class KaggleTableTests(unittest.TestCase):
    def test_missing_referenced_photos_are_not_downloaded_or_counted_as_present(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with zipfile.ZipFile(root/'download.zip', 'w') as archive:
                archive.writestr('body.csv', 'front,measurements\nfiles/0/front.jpg,files/0/measurements.json\n')
            result = inspect_tables(root)
            self.assertEqual(result[0]['rows'], 1)
            self.assertEqual(result[0]['missing_relative_asset_references'], 2)
            self.assertEqual(list(root.iterdir()), [root/'download.zip'])

    def test_csv_audit_reports_counts_without_copying_personal_values(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with zipfile.ZipFile(root/'download.zip', 'w') as archive:
                archive.writestr('table.csv', 'Age,Weight\n30,70\n40,80\n')
            result = inspect_tables(root)
            self.assertEqual(result[0]['columns'], ['Age', 'Weight'])
            self.assertEqual(result[0]['rows'], 2)
            self.assertNotIn('values', result[0])
