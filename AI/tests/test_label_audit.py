import json
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from fastapi.testclient import TestClient
from test_contour_training import fixture
from training.dataset import AnnotationStore,write_json
from training.train import read_training_data
from training.label_server import create_app
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
import merge_reviewed_datasets as merge_module
import prepare_label_audit as prepare_module
import score_label_audit as score_module


class LabelAuditTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name).resolve();self.source=self.root/'.runtime/audit';self.source.mkdir(parents=True)
        self.entries,self.labels=fixture(self.source)
        write_json(self.source/'dataset.json',{'entries':self.entries,'purpose':'label_audit'})

    def test_audit_cannot_train_even_when_reserved_test_allowed(self):
        for allow in (False,True):
            with self.assertRaisesRegex(ValueError,'라벨 기준 재검수'):
                read_training_data(self.source,enforce_holdout=False,allow_reserved_test=allow)

    def test_audit_cannot_be_merged_into_training(self):
        output=self.root/'.runtime/merged'
        with patch.object(merge_module,'ROOT',self.root):
            with self.assertRaisesRegex(ValueError,'라벨 재검수'):
                merge_module.merge(output,{'audit':'audit'})
        self.assertFalse(output.exists())

    def test_label_api_only_exposes_new_labels_and_test_only_saves(self):
        write_json(self.source/'annotations.json',{})
        write_json(self.source/'audit-reference.json',{'secret_previous_label':'weak'})
        store=AnnotationStore(self.source);key=self.entries[0]['id']
        with self.assertRaises(ValueError):store.save(key,'audit01','medium','train')
        store.save(key,'audit01','medium','test')
        client=TestClient(create_app(self.source,8017),base_url='http://127.0.0.1:8017')
        self.addCleanup(client.close)
        response=client.get('/api/entries');self.assertEqual(response.status_code,200)
        self.assertNotIn('secret_previous_label',response.text)
        self.assertEqual(response.json()['purpose'],'label_audit')

    def test_prepare_and_score_preserve_source_labels_and_blind_previous_grades(self):
        from PIL import Image
        image=self.source/'fake.jpg'
        Image.new('RGB',(128,160),(110,140,170)).save(image)
        sha=hashlib.sha256(image.read_bytes()).hexdigest()
        for entry in self.entries:
            entry['review_hashes']={'image':sha,'crop':sha}
        write_json(self.source/'dataset.json',{'entries':self.entries,'purpose':'training'})
        before=(self.source/'annotations.json').read_bytes()
        output=self.root/'.runtime/new_audit'
        with patch.object(prepare_module,'ROOT',self.root):
            self.assertEqual(prepare_module.prepare(self.source,output,1),3)
            with self.assertRaises(ValueError):prepare_module.prepare(self.source,output,1)
        store=AnnotationStore(output)
        self.assertEqual(store.annotations,{})
        client=TestClient(create_app(output,8017),base_url='http://127.0.0.1:8017')
        self.addCleanup(client.close)
        self.assertNotIn('previous_label',client.get('/api/entries').text)
        self.assertEqual(client.get('/audit-reference.json').status_code,404)
        report_path=self.root/'.runtime/audit_report.json'
        with patch.object(score_module,'ROOT',self.root):
            with self.assertRaisesRegex(ValueError,'모든 항목'):score_module.score(output,report_path)
            reference=json.loads((output/'audit-reference.json').read_text())['entries']
            for number,(key,old) in enumerate(reference.items()):
                label='exclude' if number==0 else old['previous_label']
                store.save(key,f'audit_{number}',label,'test','SYNTHETIC audit test')
            report=score_module.score(output,report_path)
            self.assertEqual(report['unchanged'],2)
            self.assertEqual(len(report['changed_items']),1)
            self.assertFalse(report['original_labels_modified'])
            self.assertEqual(before,(self.source/'annotations.json').read_bytes())
            with self.assertRaises(ValueError):score_module.score(output,report_path)

    def test_score_rejects_missing_reference_entry(self):
        write_json(self.source/'audit-reference.json',{'entries':{}})
        with patch.object(score_module,'ROOT',self.root):
            with self.assertRaisesRegex(ValueError,'대응'):
                score_module.score(self.source,self.root/'.runtime/report.json')
