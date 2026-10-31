"""Live HTTP integration check. Never prints or saves bearer tokens."""
import argparse, json, time
from pathlib import Path
import requests
p=argparse.ArgumentParser();p.add_argument('image',type=Path);p.add_argument('--base',default='http://127.0.0.1:8080');p.add_argument('--password',default='movid1234');args=p.parse_args()
s=requests.Session();base=args.base
r=s.post(base+'/api/auth/login',json={'email':'demo@movid.local','password':args.password},timeout=15)
r.raise_for_status();token=r.json()['access_token'];s.headers['Authorization']='Bearer '+token
print('Login OK')
assert requests.get(base+'/api/body-analyses',timeout=10).status_code==401
with args.image.open('rb') as f:r=s.post(base+'/api/photos',files={'image':(args.image.name,f,'image/jpeg')},data={'type':'current','side':'front'},timeout=20)
assert r.status_code==201,(r.status_code,r.text)
photo=r.json();print('Upload OK',photo['photo_id'])
assert requests.get(photo['url'],timeout=10).status_code==200
assert requests.get(photo['url']+'x',timeout=10).status_code==404
r=s.post(base+'/api/body-analyses/photo',json={'photo_id':photo['photo_id']},timeout=10)
assert r.status_code==202,(r.status_code,r.text)
ticket=r.json();started=time.perf_counter();print('Accepted',ticket['analysis_id'])
while time.perf_counter()-started<100:
 r=s.get(base+'/api/body-analyses/'+str(ticket['analysis_id']),timeout=10);r.raise_for_status();data=r.json()
 if data['status']!='pending':break
 time.sleep(1)
assert data['status']=='done',data
assert data['measures']['shoulder_tilt_deg'] is not None
assert data['balance_score'] is None
assert len(data['dinov3']['parts'])==2
assert all(len(x['cls'])==384 for x in data['dinov3']['parts'] if x['status']=='extracted')
assert data['debug_image_base64']
# A repeat of the same photo returns the persisted analysis instead of another AI call.
r=s.post(base+'/api/body-analyses/photo',json={'photo_id':photo['photo_id']},timeout=10);r.raise_for_status()
assert r.json()['analysis_id']==ticket['analysis_id']
r=s.get(base+'/api/body-analyses');r.raise_for_status();assert any(x['analysis_id']==ticket['analysis_id'] for x in r.json()['items'])
summary={'status':'passed','analysis_id':ticket['analysis_id'],'photo_id':photo['photo_id'],'polling_seconds':round(time.perf_counter()-started,2),'measures':data['measures'],'dinov3':[{'part':x['part'],'status':x['status'],'patch_shape':x.get('patch_shape')} for x in data['dinov3']['parts']],'checks':['JWT login','unauthenticated access denied','photo upload','signed image read','invalid signature rejected','async accept and polling','real MediaPipe and DINOv3','result DB query','same-photo cache','history query']}
Path('validation').mkdir(exist_ok=True);Path('validation/live-smoke.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2));print(json.dumps(summary,ensure_ascii=False,indent=2))
