from pathlib import Path
import tempfile
import unittest
from scripts.check_team_integration import inspect_sources


class TeamSourceCheckTests(unittest.TestCase):
    def test_missing_sources_are_blocked_and_never_created(self):
        with tempfile.TemporaryDirectory() as tmp:
            result=inspect_sources(tmp)
            self.assertEqual(result['status'],'blocked')
            self.assertEqual(list(Path(tmp).iterdir()),[])

    def test_placeholder_and_anthropic_fallback_are_not_claimed_as_qwen_wiring(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);shell=root/'FE/lib/app/shell/main_shell.dart';shell.parent.mkdir(parents=True)
            shell.write_text("title: '인공지능 코치', body: EmptyView(title: '대화 내역이 없어요.')")
            be=root/'BE/src/main/java/AiCoachController.java';be.parent.mkdir(parents=True)
            be.write_text('class AiCoachController { void callClaude() {} }')
            result=inspect_sources(root)
            self.assertEqual(result['status'],'blocked')
            self.assertTrue(result['frontend']['coach_placeholder_detected'])
            self.assertEqual(len(result['blockers']),2)
            self.assertEqual(result['backend']['email_verification_source_evidence'], [])
            self.assertFalse(result['backend']['actual_email_delivery_verified'])

    def test_source_evidence_is_never_reported_as_runtime_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);shell=root/'FE/lib/app/shell/main_shell.dart';shell.parent.mkdir(parents=True)
            shell.write_text("title: '인공지능 코치', body: CoachView()")
            be=root/'BE/src/main/java/AiCoachController.java';be.parent.mkdir(parents=True)
            be.write_text('class AiCoachController { String url="COACH_SERVER_URL"; String path="/v1/chat"; }')
            result=inspect_sources(root)
            self.assertEqual(result['status'],'runtime_verification_required')
            self.assertFalse(result['blockers'])
