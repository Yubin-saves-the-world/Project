import itertools
import unittest
from fastapi.testclient import TestClient
from pydantic import ValidationError
import app as api
from routine_preview import RoutinePreviewRequest, preview_routine


class RoutinePreviewTests(unittest.TestCase):
    def test_missing_confirmations_and_cautions_never_produce_exercises(self):
        missing=preview_routine(RoutinePreviewRequest())
        self.assertEqual(missing['status'],'needs_information')
        self.assertEqual(set(missing['reason_codes']),{'ADULT_CONFIRMATION_REQUIRED','CAUTION_CHECK_REQUIRED'})
        for caution in ['pain_or_injury','exercise_restriction','individual_guidance_needed']:
            result=preview_routine(RoutinePreviewRequest(adult_confirmed=True,cautions_confirmed=True,cautions=[caution]))
            self.assertEqual(result['status'],'needs_review')
            self.assertIsNone(result['routine']);self.assertEqual(result['priority_parts'],[])

    def test_all_supported_budgets_sum_exactly_and_do_not_invent_photo_targets(self):
        for goal,focus,minutes in itertools.product(['habit','strength','mobility'],['balanced','upper_body','lower_body'],range(5,46)):
            with self.subTest(goal=goal,focus=focus,minutes=minutes):
                result=preview_routine(RoutinePreviewRequest(goal=goal,focus=focus,minutes=minutes,adult_confirmed=True,cautions_confirmed=True))
                self.assertEqual(result['status'],'ready')
                self.assertEqual(sum(step['minutes'] for step in result['routine']['steps']),minutes)
                self.assertTrue(all(step['minutes']>0 and step['includes_rest'] for step in result['routine']['steps']))
                self.assertFalse(result['photo_measurements_used']);self.assertFalse(result['saved'])
                self.assertIsNone(result['model'])
                self.assertEqual(result['priority_parts_status'],'balanced_default' if focus=='balanced' else 'user_preference')
                if focus!='balanced':self.assertEqual([p['part'] for p in result['priority_parts']],[focus])

    def test_weekly_counts_and_strength_prototype_limit_are_explicit(self):
        for days in range(1,8):
            result=preview_routine(RoutinePreviewRequest(weekly_days=days,adult_confirmed=True,cautions_confirmed=True))
            self.assertEqual(sum(day['planned'] for day in result['routine']['week']),days)
        for days in range(4,8):
            result=preview_routine(RoutinePreviewRequest(goal='strength',weekly_days=days,adult_confirmed=True,cautions_confirmed=True))
            self.assertEqual(result['reason_codes'],['STRENGTH_FREQUENCY_UNSUPPORTED'])
            self.assertIsNone(result['routine'])

    def test_strict_validation_rejects_scores_images_and_invalid_preferences(self):
        for invalid in [{'minutes':True},{'weekly_days':'3'},{'adult_confirmed':'true'},
                        {'minutes':4},{'minutes':46},{'weekly_days':8},{'focus':'weak_arm'},
                        {'cautions':['pain_or_injury','pain_or_injury']},{'cautions':['unvalidated']},
                        {'balance_score':95},{'photo_measurements':{'shoulder_tilt_deg':1}}]:
            with self.subTest(invalid=invalid),self.assertRaises(ValidationError):RoutinePreviewRequest(**invalid)

    def test_http_contract_works_without_photo_or_qwen_models(self):
        client=TestClient(api.app);self.addCleanup(client.close)
        self.assertEqual(client.get('/routine').status_code,200)
        body={'adult_confirmed':True,'cautions_confirmed':True,'minutes':10,'focus':'upper_body'}
        result=client.post('/v1/routines/preview',json=body)
        self.assertEqual(result.status_code,200)
        self.assertEqual(result.json()['routine']['session_minutes'],10)
        self.assertEqual(client.post('/v1/routines/preview',json={}).json()['status'],'needs_information')
        error=client.post('/v1/routines/preview',json={'minutes':'not-number'})
        self.assertEqual(error.status_code,422)
        self.assertEqual(error.json()['detail']['code'],'VALIDATION_FAILED')
        self.assertNotIn('not-number',error.text)
