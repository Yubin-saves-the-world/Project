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
