import unittest
from unittest.mock import patch
from scripts.run_flutter_demo import coach_readiness


class CoachLauncherTests(unittest.TestCase):
    def test_only_ready_success_is_accepted(self):
        for status, body in [(503, {'status': 'ready'}), (200, {'status': 'offline'}),
                             (200, {'status': 'misconfigured'}), (200, []), (200, None)]:
            with self.subTest(status=status, body=body), patch('scripts.run_flutter_demo.http_json', return_value=(status, body)):
                self.assertFalse(coach_readiness('http://127.0.0.1:8080')[0])
        with patch('scripts.run_flutter_demo.http_json', return_value=(200, {'status': 'ready'})) as call:
            self.assertTrue(coach_readiness('http://127.0.0.1:8080')[0])
            call.assert_called_once_with('GET', 'http://127.0.0.1:8080/v1/coach/health')

    def test_unreachable_or_unreadable_health_does_not_claim_readiness(self):
        for failure in [OSError('offline'), ValueError('invalid JSON')]:
            with self.subTest(failure=type(failure).__name__), patch('scripts.run_flutter_demo.http_json', side_effect=failure):
                self.assertFalse(coach_readiness('http://127.0.0.1:8080')[0])
