import hashlib
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image
from training.dataset import normalize_image, write_json, AnnotationStore
from training import reviewed_crops as module
from training.label_server import create_app


class ReviewedCropTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.folder = self.root/'.runtime/input';self.folder.mkdir(parents=True)
        Image.fromarray(np.random.default_rng(42).integers(0,256,(300,200,3),dtype=np.uint8)).save(self.folder/'source.png')
        image = normalize_image(self.folder/'source.png')
        image.crop((20,20,100,200)).save(self.folder/'crop.png')
        self.row = {'file':'source.png','crop_file':'crop.png','source_sha256':module.digest(self.folder/'source.png'),
                    'crop_sha256':module.digest(self.folder/'crop.png'),'normalized_box':[20,20,100,200],
                    'normalized_image_size':[200,300],'original_visually_reviewed':True,'crop_visually_reviewed':True,
                    'skin_visible_confirmed':True,'upper_arm_location_confirmed':True,'reviewer':'fixture',
                    'review_reason':'synthetic fixture, not a real human label','subject_hint':'new_photo01'}
        self.manifest = self.folder/'manifest.json';self.output = self.root/'.runtime/prepared'
        write_json(self.root/'.runtime/model.json',{'path':'unused'})
        root_patch=patch.object(module,'ROOT',self.root);root_patch.start();self.addCleanup(root_patch.stop)
        dino=SimpleNamespace(extract=lambda image:({'cls':np.ones(384),'patch_mean':np.ones(384)},.01))
        self.model_patch=patch.object(module,'DinoFeatureExtractor',return_value=dino)
        self.fake=self.model_patch.start();self.addCleanup(self.model_patch.stop)

    def prepare(self):
        write_json(self.manifest,{'entries':[self.row]})
        return module.prepare(self.manifest,self.output)

    def test_exact_reviewed_crop_exports_features_without_human_labels(self):
        self.assertEqual(self.prepare(),1)
        store=AnnotationStore(self.output)
        module.validate_release(store)
        self.assertFalse(store.path.exists())
        self.assertEqual(store.view()['reviewed'],0)
        entry=next(iter(store.entries.values()))
        self.assertEqual(entry['part'],'visible_upper_arm')
        self.assertEqual(entry['subject_hint'],'new_photo01')
        self.assertEqual(np.load(store.asset(entry['id'],'features'))['vector'].shape,(768,))

    def test_unreviewed_or_changed_source_fails_before_model_or_output(self):
        self.row['crop_visually_reviewed']=False
        with self.assertRaisesRegex(ValueError,'명시적인'):
            self.prepare()
        self.fake.assert_not_called();self.assertFalse(self.output.exists())
        self.row['crop_visually_reviewed']=True
        (self.folder/'source.png').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'변경'):
            self.prepare()
        self.fake.assert_not_called();self.assertFalse(self.output.exists())

    def test_swapped_crop_pixels_are_rejected_even_with_matching_file_hash(self):
        Image.new('RGB',(80,180),'red').save(self.folder/'crop.png')
        self.row['crop_sha256']=module.digest(self.folder/'crop.png')
        with self.assertRaisesRegex(ValueError,'픽셀'):
            self.prepare()
        self.fake.assert_not_called();self.assertFalse(self.output.exists())

    def test_quarantined_asset_cannot_be_reintroduced_through_parent_manifest(self):
        old=self.folder/'quarantine_web_test';old.mkdir()
        (old/'source.png').write_bytes((self.folder/'source.png').read_bytes())
        self.row['file']='quarantine_web_test/source.png'
        with self.assertRaisesRegex(ValueError,'경로'):
            self.prepare()
        self.fake.assert_not_called()

    def test_label_server_refuses_assets_changed_after_review(self):
        self.prepare()
        create_app(self.output)
        store=AnnotationStore(self.output);entry=next(iter(store.entries.values()))
        store.asset(entry['id'],'crop').write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError,'검수'):
            create_app(self.output)
