"""Launcher preflight regressions, with no pip/model/network side effects."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts import check_environment, launch


class ZipLauncherTests(unittest.TestCase):
    def test_geometry_launcher_does_not_require_model_record(self):
        with tempfile.TemporaryDirectory() as root:
            root=Path(root);python=root/'.venv/bin/python';python.parent.mkdir(parents=True);python.touch()
            for name in ('requirements.txt','requirements-dinov3.txt','requirements-tested.lock.txt'):
                (root/name).write_text('test requirements')
            with patch.object(launch,'ROOT',root),patch('sys.argv',['launch.py','--geometry-only','--no-browser']), \
                 patch.object(launch.sys,'version_info',(3,12)),patch.object(launch.socket,'socket') as sock, \
                 patch.object(launch.subprocess,'run') as run,patch.object(launch.subprocess,'Popen') as process:
                sock.return_value.__enter__.return_value.connect_ex.return_value=1
                process.return_value.wait.return_value=0
                self.assertEqual(launch.main(),0)
                env=process.call_args.kwargs['env']
                self.assertEqual(env['AI_DISABLE_DINO'],'1')
                self.assertNotIn('AI_CONTOUR_MODEL',env)
                self.assertTrue(any(str(root/'requirements.txt') in c.args[0] for c in run.call_args_list))
                self.assertTrue(any('--geometry-only' in c.args[0] and '--model' in c.args[0] for c in run.call_args_list))
                self.assertFalse((root/'.runtime/model.json').exists())

    def test_geometry_preflight_never_imports_torch_or_fetches_dino(self):
        from types import SimpleNamespace
        loaded=[]
        def load(name):
            loaded.append(name)
            return SimpleNamespace(solutions=object())
        with patch('sys.argv',['check_environment.py','--geometry-only','--model']), \
             patch.object(check_environment.sys,'version_info',(3,12)), \
             patch.object(check_environment.importlib,'import_module',side_effect=load), \
             patch.object(check_environment,'pose_asset'), \
             patch.object(check_environment,'model_directory') as dino:
            check_environment.main()
        self.assertNotIn('torch',loaded)
        self.assertNotIn('transformers',loaded)
        self.assertIn('requests',loaded)
        dino.assert_not_called()

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

    def test_pose_asset_rejects_corruption_and_missing_explicit_path(self):
        from analyzers.pose_guard import validate_asset
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'pose.task'
            path.write_bytes(b'not the official model')
            with self.assertRaisesRegex(ValueError, 'SHA256'):
                validate_asset(path)
            with patch.dict(check_environment.os.environ, {'AI_POSE_MODEL_PATH': str(path.parent/'missing')}), \
                 patch.object(check_environment.urllib.request, 'urlopen') as network:
                with self.assertRaisesRegex(ValueError, '없습니다'):
                    check_environment.pose_asset()
                network.assert_not_called()

    def test_lock_change_invalidates_install_stamp_even_with_spaces_in_path(self):
        with tempfile.TemporaryDirectory(prefix='AI ZIP ') as root, patch.object(launch, 'ROOT', Path(root)):
            for name in ('requirements.txt', 'requirements-dinov3.txt', 'requirements-tested.lock.txt'):
                (Path(root) / name).write_text('version1')
            original = launch.dependency_digest()
            (Path(root) / 'requirements-tested.lock.txt').write_text('version2')
            self.assertNotEqual(original, launch.dependency_digest())
