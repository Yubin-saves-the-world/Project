import json
from pathlib import Path
import tempfile
import unittest
from fastapi.testclient import TestClient
from test_contour_training import fixture
from training.dataset import write_json
from training.label_server import create_app
from training.train import read_training_data

class PrescreeningTests(unittest.TestCase):
    def test_opinion_does_not_overwrite_human_label_or_training_input(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);entries,annotations=fixture(root)
            before=(root/'annotations.json').read_bytes()
            write_json(root/'pre_screening.json', {entries[0]['id']:{'status':'exclude_recommended','reason':'Example visual concern'}})
            with TestClient(create_app(root),base_url='http://127.0.0.1:8002') as client:
                data=client.get('/api/entries').json()
            self.assertFalse(data['screening_is_ground_truth'])
            self.assertEqual(data['entries'][0]['annotation']['label'],'weak')
            self.assertEqual(data['entries'][0]['pre_screening']['status'],'exclude_recommended')
            self.assertEqual((root/'annotations.json').read_bytes(),before)
            groups,_,_=read_training_data(root)
            self.assertEqual(sum(len(x) for x in groups.values()),len(entries))

    def test_suggestion_is_not_saved_as_a_human_annotation(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);entries,_=fixture(root)
            (root/'annotations.json').unlink()
            write_json(root/'pre_screening.json',{entries[0]['id']:{'status':'candidate','reason':'Visible arm'}})
            with TestClient(create_app(root),base_url='http://127.0.0.1:8002') as client:
                data=client.get('/api/entries').json()
            self.assertEqual(data['reviewed'],0)
            self.assertIsNone(data['entries'][0]['annotation'])
            self.assertFalse((root/'annotations.json').exists())

    def test_unknown_status_or_entry_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);entries,_=fixture(root)
            for values in [{entries[0]['id']:{'status':'clear','reason':'Not a screening status'}},
                           {'unknown':{'status':'candidate','reason':'Unknown entry'}}]:
                write_json(root/'pre_screening.json',values)
                with self.assertRaises(ValueError):create_app(root)
