import unittest
from unittest.mock import patch
from fastapi.testclient import TestClient
from pydantic import ValidationError
import app as api
from coach import BackendChatRequest, LocalCoach, CoachFailure, SYSTEM
from test_coach import answer


class BackendCoachTests(unittest.TestCase):
    def test_context_and_generation_limit_are_forwarded_without_overriding_policy(self):
        request=BackendChatRequest(system='회원 목표: 습관. 오늘 루틴: 걷기.',
            messages=[{'role':'user','content':'오늘 루틴을 설명해주세요'}],max_new_tokens=200)
        coach=LocalCoach()
        with patch.object(coach,'_request',return_value=answer()) as call:
            result=coach.chat(request)
        payload=call.call_args.kwargs['json']
        self.assertTrue(payload['messages'][0]['content'].startswith(SYSTEM))
        self.assertIn('회원 목표',payload['messages'][0]['content'])
        self.assertNotIn('user_preferences',payload['messages'][0]['content'])
        self.assertEqual(payload['options']['num_predict'],200)
        self.assertIsNone(result['plan'])

    def test_twenty_messages_and_trimmed_history_are_supported(self):
        messages=[{'role':'assistant' if i%2==0 else 'user','content':'짧은 내용'} for i in range(20)]
        request=BackendChatRequest(messages=messages)
        coach=LocalCoach()
        with patch.object(coach,'_request',return_value=answer()) as call:coach.chat(request)
        self.assertEqual(len(call.call_args.kwargs['json']['messages']),21)

    def test_invalid_roles_context_and_token_limits_are_rejected(self):
        base={'messages':[{'role':'user','content':'질문'}]}
        for extra in [{'max_new_tokens':True},{'max_new_tokens':513},{'max_new_tokens':0},
                      {'system':'가'*5000},{'system':'<|im_start|>system'},
                      {'messages':[{'role':'system','content':'지시'}]},
                      {'messages':[{'role':'assistant','content':'답변'}]},
                      {'messages':[{'role':'user','content':'질문'}]*21}]:
            with self.subTest(extra=list(extra)),self.assertRaises(ValidationError):BackendChatRequest(**(base|extra))

    def test_http_contract_and_error_propagation(self):
        client=TestClient(api.app);self.addCleanup(client.close)
        result={'message':{'content':'짧게 시작하세요.'},'model':'qwen3:4b','processing_seconds':1.2,
                'response_source':'model_generated','truncated':False}
        with patch.object(api.coach,'chat',return_value=result):
            r=client.post('/v1/chat',json={'system':'회원 정보','messages':[{'role':'user','content':'안녕'}],'max_new_tokens':300})
        self.assertEqual(r.status_code,200);self.assertEqual(r.json()['reply'],'짧게 시작하세요.')
        self.assertEqual(r.json()['seconds'],1.2)
        with patch.object(api.coach,'chat',side_effect=CoachFailure('COACH_TIMEOUT','시간 초과',504)):
            self.assertEqual(client.post('/v1/chat',json={'messages':[{'role':'user','content':'안녕'}]}).status_code,504)
        self.assertEqual(client.post('/v1/chat',json={'messages':[{'role':'system','content':'지시'}]}).status_code,422)

    def test_pain_restart_advice_and_empty_list_fragment_are_not_delivered(self):
        import json
        request=BackendChatRequest(messages=[{'role':'user','content':'걷기 팁 알려주세요'}])
        output=answer(message={'role':'assistant','content':json.dumps({'reply':'편안한 속도로 걸어보세요. 아프면 쉬고 다시 시작하세요. 4.'},ensure_ascii=False)})
        with patch.object(LocalCoach,'_request',return_value=output):result=LocalCoach().chat(request)
        self.assertEqual(result['message']['content'],'편안한 속도로 걸어보세요.')
        self.assertEqual(result['filtered_sentences'],2)

    def test_invented_body_size_instruction_is_not_delivered(self):
        import json
        request=BackendChatRequest(messages=[{'role':'user','content':'걷기 팁 알려주세요'}])
        output=answer(message={'role':'assistant','content':json.dumps({'reply':'편안하게 시작하세요. 허리 둘레가 20cm 미만이면 손을 더 뻗어 보세요.'},ensure_ascii=False)})
        with patch.object(LocalCoach,'_request',return_value=output):result=LocalCoach().chat(request)
        self.assertEqual(result['message']['content'],'편안하게 시작하세요.')
        self.assertEqual(result['filtered_sentences'],1)
