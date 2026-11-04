import os
from pathlib import Path
import shutil
import subprocess
import unittest
from unittest.mock import patch
from fastapi.testclient import TestClient
import app as api


class AnalysisHomeTests(unittest.TestCase):
    def test_readiness_never_accepts_request_paths_or_exposes_configured_paths(self):
        client=TestClient(api.app)
        self.addCleanup(client.close)
        with patch.dict(os.environ,{},clear=True):
            self.assertFalse(client.get('/v1/data-readiness').json()['configured'])
        with patch.dict(os.environ,{'AI_REVIEWED_DATASET':'/outside/private/data'}):
            r=client.get('/v1/data-readiness');self.assertEqual(r.status_code,503)
            self.assertNotIn('/outside/private/data',r.text)
        for url in ('/','/analysis','/assets/history.mjs'):
            self.assertEqual(client.get(url).status_code,200)

    @unittest.skipUnless(shutil.which('node'),'Node is only needed for browser module code tests')
    def test_history_allowlist_omits_images_features_and_tokens_and_handles_corruption(self):
        path=Path(__file__).resolve().parents[1]/'static/history.mjs'
        code='''import assert from 'node:assert/strict';
import {clean,save,load,remove,KEY} from MODULE;
const values=new Map();const storage={getItem:k=>values.get(k)??null,setItem:(k,v)=>values.set(k,v)};
const source={status:'done',measures:{shoulder_tilt_deg:1,pelvis_tilt_deg:NaN},debug_image_base64:'PRIVATE',dinov3:{parts:[{cls:[1],review_session:{token:'PRIVATE'}}]}};
const a=save(source,storage);assert.equal(load(storage).length,1);
assert(!storage.getItem(KEY).includes('PRIVATE'));assert.equal(clean(source).measures.pelvis_tilt_deg,null);
remove(a.id,storage);assert.equal(load(storage).length,0);
storage.setItem(KEY,'{broken');assert.deepEqual(load(storage),[]);
storage.setItem(KEY,JSON.stringify([{...a,debug_image_base64:'PRIVATE'}]));assert(!JSON.stringify(load(storage)).includes('PRIVATE'));
assert.throws(()=>clean({status:'failed'}));
for(let n=0;n<35;n++)save(source,storage);assert.equal(load(storage).length,30);
'''.replace('MODULE',repr(path.as_uri()))
        result=subprocess.run(['node','--input-type=module','-e',code],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
