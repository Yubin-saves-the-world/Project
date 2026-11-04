import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from test_contour_training import fixture
from training.dataset import write_json
from training.fit_only import fit_only
from training.independent import evaluate_independent, freeze_reference


class IndependentTests(unittest.TestCase):
    def test_partial_classes_require_opt_in_and_do_not_report_full_macro_f1(self):
        self.entries=[e for e in self.entries if not e['id'].startswith('clear-')]
        self.annotations={k:a for k,a in self.annotations.items() if not k.startswith('clear-')}
        self.persist()
        with self.assertRaisesRegex(ValueError,'모든 등급'):self.evaluate()
        report=evaluate_independent(self.model,self.train,self.test,self.output,
                                    identities_confirmed=True,allow_missing_test_classes=True)
        self.assertEqual(report['samples'],8)
        self.assertEqual(report['missing_classes'],['clear'])
        self.assertEqual(report['class_coverage'],'partial')
        self.assertIsNone(report['candidate_macro_f1'])
        self.assertIsNotNone(report['observed_classes_macro_f1'])
        self.assertEqual(report['label_counts']['clear'],0)

    def test_reported_identity_overlap_blocks_even_with_confirmation_flag(self):
        write_json(self.test/'identity-review.json',{'status':'overlap_reported'})
        with self.assertRaisesRegex(ValueError,'인물 중복'):
            self.evaluate(True)
        self.assertFalse(self.output.exists())

    def test_identity_record_is_bound_to_the_exact_dataset(self):
        write_json(self.test/'identity-review.json',{'status':'confirmed_independent','dataset_sha256':'wrong'})
        with self.assertRaisesRegex(ValueError,'검수 기록'):
            self.evaluate(True)
        self.assertFalse(self.output.exists())

    def test_reserved_evaluation_uses_model_fixed_before_labels(self):
        write_json(self.test/'dataset.json',{'entries':self.entries,'purpose':'independent_test'})
        write_json(self.test/'annotations.json',{})
        reference=freeze_reference(self.test,self.model,self.train)
        self.assertEqual((self.test/'frozen-model.json').read_bytes(),self.model.read_bytes())
        self.assertTrue(reference['frozen_before_labels'])
        for a in self.annotations.values():a['split']='test'
        write_json(self.test/'annotations.json',self.annotations)
        altered=json.loads(self.model.read_text());altered['abstain_threshold']=.7
        write_json(self.root/'altered.json',altered)
        with self.assertRaisesRegex(ValueError,'고정한 시험 모델'):
            evaluate_independent(self.root/'altered.json',self.train,self.test,self.output,identities_confirmed=True)
        report=self.evaluate()
        self.assertEqual(report['samples'],12)
        with self.assertRaisesRegex(ValueError,'라벨 저장 전'):
            freeze_reference(self.test,self.model,self.train)

    def test_model_cannot_be_fixed_after_test_labels_are_saved(self):
        write_json(self.test/'dataset.json',{'entries':self.entries,'purpose':'independent_test'})
        with self.assertRaisesRegex(ValueError,'라벨 저장 전'):
            freeze_reference(self.test,self.model,self.train)
        self.assertFalse((self.test/'frozen-model.json').exists())

    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.train=self.root/'train';self.test=self.root/'test'
        self.train.mkdir();self.test.mkdir();fixture(self.train)
        self.entries,self.annotations=fixture(self.test)
        for entry in self.entries:entry['source_sha256']='unseen-'+entry['source_sha256']
        for a in self.annotations.values():a['subject_id']='unseen-'+a['subject_id']
        for entry in self.entries:
            p=self.test/entry['features'];v=np.load(p)['vector'];v[10]+=.01;np.savez_compressed(p,vector=v)
        self.persist();fit_only(self.train,self.root/'model')
        self.model=self.root/'model/model.json';self.output=self.root/'evaluation.json'

    def persist(self):
        write_json(self.test/'dataset.json',{'entries':self.entries})
        write_json(self.test/'annotations.json',self.annotations)

    def evaluate(self,confirmed=True):
        return evaluate_independent(self.model,self.train,self.test,self.output,identities_confirmed=confirmed)

    def test_explicit_identity_confirmation_and_training_provenance_required(self):
        with self.assertRaisesRegex(ValueError,'인물'):self.evaluate(False)
        annotations=json.loads((self.train/'annotations.json').read_text())
        annotations['weak-0']['reason']='changed provenance';write_json(self.train/'annotations.json',annotations)
        with self.assertRaisesRegex(ValueError,'학습 자료'):self.evaluate()
        self.assertFalse(self.output.exists())

    def test_renaming_subjects_does_not_hide_duplicate_photo(self):
        self.entries[0]['source_sha256']='weak-0';self.persist()
        with self.assertRaisesRegex(ValueError,'원본 사진'):self.evaluate()

    def test_same_features_are_rejected_even_with_new_photo_ids(self):
        np.savez_compressed(self.test/'features/weak-0.npz',vector=np.load(self.train/'features/weak-0.npz')['vector'])
        with self.assertRaisesRegex(ValueError,'같은 특징'):self.evaluate()

    def test_frozen_model_report_keeps_coverage_separate_and_does_not_modify_model(self):
        before=self.model.read_bytes();report=self.evaluate()
        self.assertEqual(report['samples'],12)
        self.assertFalse(report['identity_automatically_verified'])
        self.assertEqual(report['threshold'],.6)
        self.assertIn('accepted_coverage',report)
        self.assertEqual(self.model.read_bytes(),before)
        with self.assertRaisesRegex(ValueError,'덮어쓰지'):self.evaluate()
