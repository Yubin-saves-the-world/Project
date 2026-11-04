import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock,patch
from fastapi import FastAPI
from fastapi.testclient import TestClient
from app import save_image
from bridge.api import install
from coach import CoachFailure


class BridgeCoachTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.coach=MagicMock()
        self.coach.chat.return_value={'message':{'content':'작은 목표부터 시작하세요.'},'model':'qwen3:4b',
            'response_source':'model_generated','plan':None}
        app=FastAPI();app.state.engine=object()
        self.service=install(app,self.tmp.name,'http://127.0.0.1:8082',save_image,coach=self.coach)
        self.addCleanup(self.service.close);self.client=TestClient(app);self.addCleanup(self.client.close)
        self.auth={'Authorization':'Bearer alice'}
        def backend(method,url,headers,**kwargs):
            uid={'Bearer alice':1,'Bearer bob':2}.get(headers.get('Authorization'))
            return SimpleNamespace(status_code=200 if uid else 401,json=lambda:{'user_id':uid,
                'onboarding_completed':True,'body_photo_agreed':True,'ai_processing_agreed':True})
        self.mock=patch('bridge.api.requests.Session.request',side_effect=backend);self.mock.start();self.addCleanup(self.mock.stop)

    def test_authenticated_pair_is_persisted_owner_scoped_and_deleted(self):
        self.assertEqual(self.client.get('/api/ai-coach/messages').status_code,401)
        r=self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':'안녕하세요','user_id':2})
        self.assertEqual(r.status_code,200);self.assertEqual(r.json()['assistant_message']['model'],'qwen3:4b')
        self.assertEqual(len(self.client.get('/api/ai-coach/messages',headers=self.auth).json()['messages']),2)
        self.assertEqual(self.client.get('/api/ai-coach/messages',headers={'Authorization':'Bearer bob'}).json()['messages'],[])
        self.assertEqual(self.client.delete('/api/ai-coach/messages',headers=self.auth).json()['deleted'],2)

    def test_model_failure_does_not_save_orphan_message(self):
        self.coach.chat.side_effect=CoachFailure('COACH_OFFLINE','모델 연결 필요',503)
        r=self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':'안녕하세요'})
        self.assertEqual(r.status_code,503)
        self.assertEqual(self.service.chat_history(1),[])
        self.coach.chat.side_effect=None
        self.assertEqual(self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':'다시 시작'}).status_code,200)

    def test_history_and_rule_plan_attribution_are_preserved(self):
        for question in ['처음 시작해요','앞에서 말한 방법을 설명해 주세요']:
            self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':question})
        history=self.coach.chat.call_args.args[0].messages
        self.assertEqual([m.role for m in history],['user','assistant','user'])
        self.coach.chat.return_value={'message':{'content':'안내입니다'},'model':None,'response_source':'rule_based_plan',
            'plan':{'weekly_days':3,'session_minutes':10,'steps':[{'title':'걷기','minutes':10}]}}
        r=self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':'10분 계획'})
        self.assertIn('규칙 기반 일반 예시',r.json()['assistant_message']['content'])
        self.assertIsNone(r.json()['assistant_message']['model'])

    def test_busy_delete_and_invalid_content(self):
        self.service.chat_lock.acquire()
        try:
            self.assertEqual(self.client.delete('/api/ai-coach/messages',headers=self.auth).status_code,409)
        finally:self.service.chat_lock.release()
        for text in ['',True,'x'*501]:
            self.assertEqual(self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':text}).status_code,422)

    def analysis(self, uid=1, status='done', measures=None):
        import json
        with self.service.db() as db:
            return db.execute('INSERT INTO analyses(uid,photo_id,status,payload,created_at) VALUES(?,?,?,?,?)',
                (uid,1,status,json.dumps({'measures':measures if measures is not None else {'shoulder_tilt_deg':1.2},
                    'debug_image_base64':'private-photo','features':[99]}),'2026-11-04T00:00:00+00:00')).lastrowid

    def test_owned_measurements_and_profile_exclude_photo_features(self):
        aid=self.analysis();self.coach.chat.return_value['context_used']=True
        r=self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':'설명','analysis_id':aid,
            'profile':{'goal':'mobility','weekly_days':2,'minutes':10}})
        self.assertEqual(r.status_code,200)
        request=self.coach.chat.call_args.args[0]
        self.assertEqual(request.profile.minutes,10)
        self.assertEqual(request.profile.weekly_days,2)
        self.assertEqual(request.measurements.shoulder_tilt_deg,1.2)
        self.assertNotIn('private-photo',request.model_dump_json())
        self.assertNotIn('features',request.model_dump_json())
        self.assertEqual(r.json()['context'],{'analysis_id':aid,'measurements_provided':True,'context_used':True})
        self.coach.chat.reset_mock()
        r=self.client.post('/api/ai-coach/messages',headers={'Authorization':'Bearer bob'},json={'content':'설명','analysis_id':aid})
        self.assertEqual(r.status_code,404);self.coach.chat.assert_not_called()

    def test_bad_or_unavailable_analysis_does_not_call_model(self):
        pending=self.analysis(status='pending');empty=self.analysis(measures={})
        invalid=self.analysis(measures={'shoulder_tilt_deg':True})
        for aid,code in [(True,422),(-1,422),('1',422),(999,404),(pending,409),(empty,422),(invalid,422)]:
            with self.subTest(aid=aid):
                r=self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':'설명','analysis_id':aid})
                self.assertEqual(r.status_code,code)
        self.coach.chat.assert_not_called();self.assertEqual(self.service.chat_history(1),[])

    def test_profile_validation_and_legacy_request(self):
        r=self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':'계획','profile':{'minutes':True}})
        self.assertEqual(r.status_code,422);self.coach.chat.assert_not_called()
        r=self.client.post('/api/ai-coach/messages',headers=self.auth,json={'content':'계획'})
        self.assertEqual(r.status_code,200)
        self.assertEqual(self.coach.chat.call_args.args[0].profile.minutes,20)
        self.assertFalse(r.json()['context']['measurements_provided'])
