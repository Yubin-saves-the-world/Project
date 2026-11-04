"""Launcher preflight regressions, with no pip/model/network side effects."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts import check_environment, launch


class ZipLauncherTests(unittest.TestCase):
    def test_occupied_port_is_rejected_before_creating_environment(self):
        with patch('sys.argv', ['launch.py', '--no-browser']), patch.object(launch.sys, 'version_info', (3, 12)), \
             patch.object(launch.socket, 'socket') as socket, patch.object(launch.subprocess, 'run') as run:
            socket.return_value.__enter__.return_value.connect_ex.return_value = 0
            with self.assertRaisesRegex(SystemExit, '사용 중'):
                launch.main()
            run.assert_not_called()

    def test_missing_local_model_does_not_fall_back_to_remote_repo(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(check_environment.os.environ,
                {'DINO_MODEL_PATH': str(Path(root) / 'missing')}):
            with self.assertRaisesRegex(ValueError, '존재하지'):
                check_environment.model_directory()

    def test_incomplete_model_is_rejected(self):
        with tempfile.TemporaryDirectory() as root, patch.dict(check_environment.os.environ, {'DINO_MODEL_PATH': root}):
            with self.assertRaisesRegex(ValueError, 'model.safetensors'):
                check_environment.model_directory()

    def test_lock_change_invalidates_install_stamp_even_with_spaces_in_path(self):
        with tempfile.TemporaryDirectory(prefix='AI ZIP ') as root, patch.object(launch, 'ROOT', Path(root)):
            for name in ('requirements.txt', 'requirements-dinov3.txt', 'requirements-tested.lock.txt'):
                (Path(root) / name).write_text('version1')
            original = launch.dependency_digest()
            (Path(root) / 'requirements-tested.lock.txt').write_text('version2')
            self.assertNotEqual(original, launch.dependency_digest())
