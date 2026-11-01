from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from test_contour_training import fixture
from training.dataset import AnnotationStore, write_json
from training.train import read_training_data
from training.fit_only import fit_only
from scripts import merge_reviewed_datasets as merging


class ReservedTestTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name).resolve();self.source=self.root/'.runtime/reserved'
        self.source.mkdir(parents=True);entries,annotations=fixture(self.source)
        for e in entries:e['split_hint']='test'
        for a in annotations.values():a['split']='test'
        write_json(self.source/'dataset.json',{'entries':entries,'purpose':'independent_test'})
        write_json(self.source/'annotations.json',annotations)

    def test_test_split_is_locked_at_storage_boundary(self):
        store=AnnotationStore(self.source)
        self.assertEqual(store.view()['purpose'],'independent_test')
        with self.assertRaisesRegex(ValueError,'test로만'):
            store.save('weak-0','weak-0','weak','train')
        self.assertEqual(store.save('weak-0','weak-0','weak','test')['split'],'test')

    def test_training_and_merge_cannot_consume_reserved_test(self):
        with self.assertRaisesRegex(ValueError,'학습에'):read_training_data(self.source,enforce_holdout=False)
        with self.assertRaisesRegex(ValueError,'학습에'):fit_only(self.source,self.root/'model')
        with patch.object(merging,'ROOT',self.root):
            with self.assertRaisesRegex(ValueError,'통합할 수'):
                merging.merge(self.root/'.runtime/merged',{'reserved':'reserved'})
        self.assertFalse((self.root/'model').exists());self.assertFalse((self.root/'.runtime/merged').exists())

    def test_only_explicit_evaluation_read_can_load_all_test_rows(self):
        groups,classes,_=read_training_data(self.source,enforce_holdout=False,allow_reserved_test=True)
        self.assertEqual(len(groups['test']),12)
        self.assertEqual(set(classes),{'weak','medium','clear'})
        store=AnnotationStore(self.source);changed=dict(store.annotations)
        changed['weak-0']={**changed['weak-0'],'split':'train'}
        write_json(store.path,changed)
        with self.assertRaisesRegex(ValueError,'모든 라벨'):
            read_training_data(self.source,enforce_holdout=False,allow_reserved_test=True)
