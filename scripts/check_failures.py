"""Live negative and ownership checks for the integration server."""
import io,json,time,uuid
from pathlib import Path
from PIL import Image
import requests
class TimedSession(requests.Session):
    def request(self, *args, **kwargs):
        kwargs.setdefault('timeout', 20)
        return super().request(*args, **kwargs)

base='http://127.0.0.1:8080'
s=TimedSession();r=s.post(base+'/api/auth/login',json={'email':'demo@movid.local','password':'movid1234'});r.raise_for_status();s.headers['Authorization']='Bearer '+r.json()['access_token']
invalid=s.post(base+'/api/photos',files={'image':('fake.jpg',b'not an image','image/jpeg')},data={'type':'current'})
assert invalid.status_code==400,invalid.text
missing=s.post(base+'/api/body-analyses/photo',json={});assert missing.status_code==400
before=s.get(base+'/api/body-analyses/usage').json()['used']
buf=io.BytesIO();Image.new('RGB',(256,256),'white').save(buf,format='JPEG')
r=s.post(base+'/api/photos',files={'image':('blank.jpg',buf.getvalue(),'image/jpeg')},data={'type':'current','side':'front'});r.raise_for_status();photo=r.json()
r=s.post(base+'/api/body-analyses/photo',json={'photo_id':photo['photo_id']});r.raise_for_status();aid=r.json()['analysis_id']
for _ in range(95):
 result=s.get(base+f'/api/body-analyses/{aid}').json()
 if result['status']!='pending':break
 time.sleep(1)
assert result['status']=='failed' and result['error_code']=='IMAGE_BLURRY',result
assert s.get(base+'/api/body-analyses/usage').json()['used']==before
# A second real account cannot read or delete the first account's objects.
uid=uuid.uuid4().hex[:10];other=TimedSession()
r=other.post(base+'/api/users',json={'email':uid+'@example.com','password':'check1234','nickname':uid,'terms_agreed':True,'privacy_agreed':True,'body_photo_agreed':True,'ai_processing_agreed':True});assert r.status_code==201,r.text
r=other.post(base+'/api/auth/login',json={'email':uid+'@example.com','password':'check1234'});r.raise_for_status();other.headers['Authorization']='Bearer '+r.json()['access_token']
r=other.post(base+'/api/users/me/profile',json={'height_cm':170,'weight_kg':65,'age':20,'gender':'none','goal_type':'posture','weekly_frequency':3,'experience_level':'under3m'});assert r.status_code==201,r.text
assert other.get(base+f'/api/body-analyses/{aid}').status_code==404
assert other.delete(base+'/api/photos/'+str(photo['photo_id'])).status_code==404
assert s.delete(base+'/api/photos/'+str(photo['photo_id'])).status_code==204
assert requests.get(photo['url'],timeout=10).status_code==404
summary={'status':'passed','checks':['invalid image rejected','missing photo ID rejected','blank photo transitions to failed','quality failure does not spend quota','other user cannot read analysis','other user cannot delete photo','deleted photo URL invalidated']}
Path('validation').mkdir(exist_ok=True);Path('validation/negative-smoke.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
