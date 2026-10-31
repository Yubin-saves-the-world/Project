import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from scripts.prepare_reviewed_arm_photos import ROOT, prepare

class ReviewedArmPreparationTests(unittest.TestCase):
    def test_quarantined_inputs_are_rejected(self):
        with self.assertRaisesRegex(ValueError,'격리'):
            prepare(ROOT/'.runtime/quarantine_web_test/manifest.json',ROOT/'.runtime/unused_test_output')

    def test_unreviewed_manifest_cannot_prepare(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'.runtime') as directory:
            p=Path(directory);(p/'manifest.json').write_text(json.dumps([{'review_status':'not_reviewed'}]))
            with self.assertRaisesRegex(ValueError,'사전검수'):
                prepare(p/'manifest.json',p/'output')
            self.assertFalse((p/'output').exists())

    def test_changed_photo_invalidates_approval(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'.runtime') as directory:
            p=Path(directory);(p/'photo.jpg').write_bytes(b'changed')
            (p/'manifest.json').write_text(json.dumps([{'file':'photo.jpg','review_status':'approved_for_arm_labeling','review_reason':'manually checked','sha256':hashlib.sha256(b'original').hexdigest()}]))
            with self.assertRaisesRegex(ValueError,'일치'):
                prepare(p/'manifest.json',p/'output')
            self.assertFalse((p/'output').exists())
