import json
import tempfile
import unittest
from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import patch
from unittest.mock import MagicMock

from fastapi import FastAPI
from fastapi.testclient import TestClient
from app import save_image
from bridge.api import install, now
from bridge.workouts import today, DAYS


class DemoWorkoutTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        app = FastAPI();app.state.engine = object()
        self.service = install(app, self.temp.name, 'http://127.0.0.1:8082', save_image)
        self.addCleanup(self.service.close)
        self.client = TestClient(app);self.addCleanup(self.client.close)
        self.auth = {'Authorization': 'Bearer alice'}
        self.bob = {'Authorization': 'Bearer bob'}
        self.profile = {'age': 25, 'goal_type': 'posture', 'weekly_frequency': 3}
        def backend(method, url, headers, **kwargs):
            uid = {'Bearer alice': 1, 'Bearer bob': 2}.get(headers.get('Authorization'))
            if not uid:return SimpleNamespace(status_code=401, json=lambda: {})
            body = self.profile if url.endswith('/profile') else {'user_id': uid, 'onboarding_completed': True,
                'body_photo_agreed': True, 'ai_processing_agreed': True}
            return SimpleNamespace(status_code=200, json=lambda: body)
        mock = patch('bridge.api.requests.Session.request', side_effect=backend)
        mock.start();self.addCleanup(mock.stop)
        with self.service.db() as db:
            self.aid = db.execute('INSERT INTO analyses(uid,photo_id,status,payload,created_at) VALUES(?,?,?,?,?)',
                (1, 1, 'done', json.dumps({'measures': {'shoulder_tilt_deg': 1.2}}), now())).lastrowid

    def generate(self, **extra):
        response = self.client.post('/api/routines', headers=self.auth, json={'analysis_id': self.aid, **extra})
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()['routines']

    def start(self, routine=None):
        routine = routine or self.generate()[0]
        response = self.client.post('/api/workout-logs', headers=self.auth,
            json={'routine_id': routine['routine_id'], 'exercise_id': routine['items'][0]['exercise']['exercise_id']})
        self.assertIn(response.status_code, (200, 201), response.text)
        return response.json()

    def add(self, lid, **extra):
        return self.client.post(f'/api/workout-logs/{lid}/sets', headers=self.auth,
            json={'client_set_id': 'set-001', 'set_no': 1, 'weight_kg': 2, 'reps': 5, 'is_done': True, 'rest_sec': 60, **extra})

    def records(self, **extra):
        return self.client.get('/api/workout-logs', headers=self.auth,
            params={'start_date': today().isoformat(), 'end_date': today().isoformat(), **extra})

    def test_analysis_to_week_detail_home_sets_completion_and_calendar(self):
        routines = self.generate()
        self.assertEqual(len(routines), 3)
        first = routines[0];rid = first['routine_id']
        self.assertEqual(first['scheduled_date'], today().isoformat())
        self.assertFalse(first['generation']['photo_measurements_used'])
        self.assertEqual(first['generation']['cautions_status'], 'not_collected')
        self.assertEqual(first['items'][0]['target_reps'], 5)
        self.assertIn('판정', first['items'][0]['reason'])
        monday = today() - timedelta(days=today().weekday())
        week = self.client.get('/api/routines/weekly', headers=self.auth, params={'week_start': monday.isoformat()}).json()
        self.assertEqual(len(week['days']), 7)
        self.assertEqual(week['days'][today().weekday()]['routine']['routine_id'], rid)
        home = self.client.get('/api/routines/today', headers=self.auth).json()
        self.assertEqual(home['routine']['routine_id'], rid)
        log = self.start(first);lid = log['log_id']
        self.assertEqual(self.records().json()['summary']['workout_dates'], [])
        self.assertEqual(self.add(lid).status_code, 200)
        self.assertEqual(self.add(lid, client_set_id='set-002', set_no=2, weight_kg=3, reps=6).status_code, 200)
        response = self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={'memo': '시연 완료'})
        self.assertEqual(response.status_code, 200, response.text)
        completed = response.json()
        self.assertEqual(completed['set_count'], 2)
        self.assertEqual(completed['total_volume_kg'], 28)
        self.assertEqual(completed['routine_progress'], {'done': 1, 'total': 2})
        records = self.records().json()
        self.assertEqual(records['summary']['workout_dates'], [today().isoformat()])
        self.assertEqual(records['summary']['total_sets'], 2)
        self.assertEqual(records['summary']['total_volume_kg'], 28)
        detail = self.client.get(f'/api/routines/{rid}', headers=self.auth).json()
        self.assertTrue(detail['items'][0]['done']);self.assertFalse(detail['items'][1]['done'])

    def test_all_exercises_must_be_completed_for_routine_done(self):
        routine = self.generate()[0]
        for index, item in enumerate(routine['items']):
            log = self.client.post('/api/workout-logs', headers=self.auth, json={
                'routine_id': routine['routine_id'], 'exercise_id': item['exercise']['exercise_id']}).json()
            self.add(log['log_id'])
            result = self.client.patch(f"/api/workout-logs/{log['log_id']}/complete", headers=self.auth, json={}).json()
            self.assertEqual(result['routine_progress']['done'], index + 1)
        self.assertEqual(result['routine_status'], 'done')

    def test_retries_do_not_duplicate_plans_logs_sets_or_completion(self):
        first = self.generate()
        self.assertEqual([r['routine_id'] for r in first], [r['routine_id'] for r in self.generate()])
        log = self.start(first[0]);lid = log['log_id']
        self.assertEqual(self.start(first[0])['log_id'], lid)
        self.add(lid);self.add(lid)
        self.assertEqual(len(self.client.get(f'/api/workout-logs/{lid}', headers=self.auth).json()['sets']), 1)
        a = self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={}).json()
        b = self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={}).json()
        self.assertEqual(a, b)
        self.assertEqual(self.add(lid).status_code, 200)
        self.assertEqual(self.add(lid, reps=7).status_code, 409)

    def test_new_sets_and_empty_completion_are_rejected_after_completion(self):
        lid = self.start()['log_id']
        self.assertEqual(self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={}).status_code, 409)
        self.add(lid)
        self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={})
        self.assertEqual(self.add(lid, client_set_id='set-002', set_no=2).status_code, 409)

    def test_plan_analysis_and_workout_ownership(self):
        routine = self.generate()[0];rid = routine['routine_id'];lid = self.start(routine)['log_id']
        for path in [f'/api/routines/{rid}', f'/api/workout-logs/{lid}']:
            self.assertEqual(self.client.get(path, headers=self.bob).status_code, 404)
        self.assertEqual(self.client.post('/api/routines', headers=self.bob, json={'analysis_id': self.aid}).status_code, 404)
        self.assertEqual(self.client.post('/api/workout-logs', headers=self.bob, json={'exercise_id': 910001, 'routine_id': rid}).status_code, 404)
        self.assertEqual(self.client.delete(f'/api/workout-logs/{lid}', headers=self.bob).status_code, 404)
        self.assertEqual(self.client.get('/api/routines/today', headers=self.bob).json()['routine'], None)
        self.assertEqual(self.client.get('/api/routines/today').status_code, 401)

    def test_set_versions_conflicting_ids_and_actual_statistics(self):
        lid = self.start()['log_id'];self.add(lid)
        self.assertEqual(self.add(lid, client_set_id='another').status_code, 409)
        entry = self.client.get(f'/api/workout-logs/{lid}', headers=self.auth).json()['sets'][0]
        path = f"/api/workout-logs/{lid}/sets/{entry['set_id']}"
        self.assertEqual(self.client.patch(path, headers=self.auth, json={'version': 1, 'reps': 10}).status_code, 200)
        self.assertEqual(self.client.patch(path, headers=self.auth, json={'version': 1, 'reps': 12}).status_code, 409)
        result = self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={}).json()
        self.assertEqual(result['total_volume_kg'], 20)
        self.assertEqual(self.client.delete(path, headers=self.bob).status_code, 404)
        self.assertEqual(self.client.delete(f'/api/workout-logs/{lid}', headers=self.auth).status_code, 204)
        self.assertEqual(self.records().json()['summary']['workout_dates'], [])

    def test_profile_cautions_analysis_status_and_body_validation(self):
        for profile in [{'age': 17}, {'weekly_frequency': True}, {'weekly_frequency': 8}, {'goal_type': 'unknown'}]:
            original = dict(self.profile);self.profile.update(profile)
            self.assertEqual(self.client.post('/api/routines', headers=self.auth, json={'analysis_id': self.aid}).status_code, 422)
            self.profile = original
        self.assertEqual(self.client.post('/api/routines', headers=self.auth, json={'analysis_id': self.aid, 'cautions': ['pain']}).status_code, 409)
        self.assertEqual(self.client.post('/api/routines', headers=self.auth, json={'analysis_id': True}).status_code, 422)
        with self.service.db() as db:db.execute("UPDATE analyses SET status='failed' WHERE id=?", (self.aid,))
        self.assertEqual(self.client.post('/api/routines', headers=self.auth, json={'analysis_id': self.aid}).status_code, 409)

    def test_invalid_set_values_never_write_a_record(self):
        lid = self.start()['log_id']
        for values in [{'weight_kg': True}, {'weight_kg': '2'}, {'weight_kg': -1}, {'weight_kg': 501},
                       {'reps': True}, {'reps': 0}, {'reps': 101}, {'set_no': 0}, {'set_no': '1'},
                       {'rest_sec': -1}, {'is_done': 'true'}, {'client_set_id': '../bad'}]:
            with self.subTest(values=values):self.assertEqual(self.add(lid, **values).status_code, 422)
        self.assertEqual(self.client.get(f'/api/workout-logs/{lid}', headers=self.auth).json()['sets'], [])

    def test_dates_filters_skip_and_exercise_catalog(self):
        self.assertEqual(self.client.get('/api/routines/weekly', headers=self.auth, params={'week_start': '2026-11-04'}).status_code, 422)
        self.assertEqual(self.records(end_date=(today() + timedelta(days=92)).isoformat()).status_code, 422)
        self.assertEqual(self.records(status='anything').status_code, 422)
        routine = self.generate()[0];rid = routine['routine_id']
        self.assertEqual(self.client.patch(f'/api/routines/{rid}', headers=self.auth, json={'status': 'done'}).status_code, 422)
        self.assertEqual(self.client.patch(f'/api/routines/{rid}', headers=self.auth, json={'status': 'skipped'}).json()['status'], 'skipped')
        self.assertEqual(self.client.post('/api/workout-logs', headers=self.auth, json={'routine_id': rid, 'exercise_id': 910001}).status_code, 409)
        self.assertEqual(self.client.patch(f'/api/routines/{rid}', headers=self.auth, json={'status': 'planned'}).status_code, 200)
        self.assertEqual(self.client.post('/api/workout-logs', headers=self.auth, json={'routine_id': rid, 'exercise_id': 910003}).status_code, 422)
        self.assertEqual(self.client.get('/api/exercises', headers=self.auth, params={'target_part':'leg'}).json()['total'], 2)
        self.assertEqual(self.client.get('/api/exercises/999', headers=self.auth).status_code, 404)

    def test_frequency_controls_exact_number_of_days(self):
        for frequency in range(1, 8):
            with self.subTest(frequency=frequency):
                with self.service.db() as db:db.execute('DELETE FROM demo_routines')
                self.profile['weekly_frequency'] = frequency
                routines = self.generate(cautions=[])
                self.assertEqual(len(routines), frequency)
                self.assertEqual([r['scheduled_date'] for r in routines], [(today() + timedelta(days=d)).isoformat() for d in DAYS[frequency]])
                self.assertEqual(routines[0]['generation']['cautions_status'], 'none_reported')

    def test_regeneration_updates_unstarted_days_but_preserves_recorded_plans(self):
        original = self.generate();lid = self.start(original[0])['log_id'];self.add(lid)
        self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={})
        self.profile.update(weekly_frequency=2, goal_type='muscle')
        regenerated = self.generate()
        self.assertEqual(len(regenerated), 2)
        self.assertEqual(regenerated[0]['routine_id'], original[0]['routine_id'])
        self.assertTrue(regenerated[0]['items'][0]['done'])
        self.assertEqual(regenerated[0]['generation']['profile_goal'], 'posture')
        self.assertEqual(regenerated[1]['generation']['profile_goal'], 'muscle')
        with self.service.db() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM demo_routines').fetchone()[0], 2)

    def test_completed_log_cannot_become_empty_but_can_be_removed(self):
        lid = self.start()['log_id'];self.add(lid)
        log = self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={}).json()
        sid = log['sets'][0]['set_id'];path = f'/api/workout-logs/{lid}/sets/{sid}'
        self.assertEqual(self.client.delete(path, headers=self.auth).status_code, 409)
        self.assertEqual(self.client.patch(path, headers=self.auth, json={'version': 1, 'is_done': False}).status_code, 409)
        self.assertEqual(self.client.delete(f'/api/workout-logs/{lid}', headers=self.auth).status_code, 204)

    def test_store_is_persistent_after_a_new_service_instance(self):
        rid = self.generate()[0]['routine_id'];lid = self.start()['log_id'];self.add(lid)
        self.client.patch(f'/api/workout-logs/{lid}/complete', headers=self.auth, json={})
        from bridge.workouts import WorkoutStore
        reopened = WorkoutStore(self.service)
        with self.service.db() as db:
            self.assertTrue(reopened.routine(db, 1, rid)['items'][0]['done'])
            self.assertEqual(reopened.log(db, 1, lid)['status'], 'completed')

    def test_account_coach_receives_only_the_owners_saved_routine(self):
        rid = self.generate()[0]['routine_id']
        coach = MagicMock()
        coach.chat.return_value = {'message': {'content': '기록 확인'}, 'response_source': 'model_generated', 'model': 'qwen3:4b', 'context_used': True}
        self.service.coach = coach
        response = self.client.post('/api/ai-coach/messages', headers=self.auth, json={'content': '설명 부탁해요'})
        self.assertEqual(response.json()['context']['saved_routine_id'], rid)
        context = coach.chat.call_args.args[0].saved_routine
        self.assertEqual(context.routine_id, rid)
        self.assertEqual(context.items[0].reps, 5)
        self.client.post('/api/ai-coach/messages', headers=self.bob, json={'content': '설명 부탁해요'})
        self.assertIsNone(coach.chat.call_args.args[0].saved_routine)

    def test_expired_session_is_preserved_as_aborted_and_new_start_is_possible(self):
        routine = self.generate()[0];old = self.start(routine)['log_id']
        self.add(old)
        with self.service.db() as db:
            db.execute("UPDATE demo_logs SET started_at='2000-01-01T00:00:00+00:00' WHERE id=?", (old,))
        self.assertEqual(self.add(old, client_set_id='set-002', set_no=2).status_code, 409)
        self.assertEqual(self.client.patch(f'/api/workout-logs/{old}/complete', headers=self.auth, json={}).status_code, 409)
        new = self.start(routine)['log_id']
        self.assertNotEqual(new, old)
        previous = self.client.get(f'/api/workout-logs/{old}', headers=self.auth).json()
        self.assertEqual(previous['status'], 'aborted')
        self.assertEqual(len(previous['sets']), 1)
        self.assertEqual(self.records().json()['summary']['workout_dates'], [])

    def test_record_access_does_not_require_photo_or_ai_processing_consent(self):
        self.generate()
        user = {'user_id': 1, 'onboarding_completed': True,
                'body_photo_agreed': False, 'ai_processing_agreed': False}
        with patch('bridge.api.requests.Session.request', return_value=SimpleNamespace(status_code=200, json=lambda: user)):
            self.assertEqual(self.client.get('/api/routines/today', headers=self.auth).status_code, 200)
            self.assertEqual(self.records().status_code, 200)
            self.assertEqual(self.client.post('/api/workout-logs', headers=self.auth, json={'exercise_id':910001}).status_code, 201)
            self.assertEqual(self.client.post('/api/routines', headers=self.auth, json={'analysis_id':self.aid}).status_code, 403)
            self.assertEqual(self.client.get('/api/ai-coach/messages', headers=self.auth).status_code, 403)


if __name__ == '__main__':unittest.main()
