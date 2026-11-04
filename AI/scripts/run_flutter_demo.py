"""Run original Flutter + Spring with an AI-owned compatibility layer.
No canonical FE/BE source is edited. Generated build files stay under AI/.runtime.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import time
import urllib.request
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from scripts.stage_team_runtime import RUNTIME, stage, verify_originals
from scripts.check_team_integration import inspect_sources


def http_json(method, url, body=None, headers=None):
    headers = dict(headers or {})
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read())


def wait_url(url, process, seconds=180):
    for _ in range(seconds):
        if process.poll() is not None:
            raise RuntimeError('서버가 종료됐습니다. AI/.runtime/flutter_demo 로그를 확인하세요.')
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                if response.status == 200:
                    return
        except OSError:
            pass
        time.sleep(1)
    raise RuntimeError('서버 준비 시간이 초과됐습니다. 실행 로그를 확인하세요.')


def coach_readiness(base):
    """Report model readiness without sending or saving a conversation."""
    try:
        status, result = http_json('GET', base + '/v1/coach/health')
        if status == 200 and isinstance(result, dict) and result.get('status') == 'ready':
            return True, 'Qwen3 코치 준비 완료'
        return False, 'Qwen3 코치가 준비되지 않았습니다. Ollama 실행과 모델 설치를 확인하세요.'
    except (OSError, ValueError, TypeError):
        return False, '코치 연결 상태를 확인하지 못했습니다. 서버 로그를 확인하세요.'


def seed_account(base, password):
    email = 'demo@movid.local'
    status, _ = http_json('POST', base + '/api/users', {
        'email': email, 'password': password, 'nickname': 'MOVID 시연',
        'terms_agreed': True, 'privacy_agreed': True,
        'body_photo_agreed': True, 'ai_processing_agreed': True})
    if status not in (201, 409):
        raise RuntimeError('시연 계정 준비 실패: ' + str(status))
    status, login = http_json('POST', base + '/api/auth/login', {'email': email, 'password': password})
    if status != 200:
        raise RuntimeError('시연 계정 로그인 실패. 기존 비밀번호를 AI_DEMO_PASSWORD로 지정하세요.')
    headers = {'Authorization': 'Bearer ' + login['access_token']}
    status, _ = http_json('GET', base + '/api/users/me/profile', headers=headers)
    if status == 404:
        status, _ = http_json('POST', base + '/api/users/me/profile', {
            'height_cm': 170, 'weight_kg': 65, 'age': 25, 'gender': 'none',
            'goal_type': 'posture', 'weekly_frequency': 3, 'experience_level': 'under3m'}, headers)
        if status != 201:
            raise RuntimeError('시연 프로필 준비 실패: ' + str(status))
    elif status != 200:
        raise RuntimeError('시연 프로필 조회 실패')
    print('로컬 시연 계정: demo@movid.local / ' + ('최초 기본 비밀번호 movid1234' if password == 'movid1234' else '지정한 AI_DEMO_PASSWORD 사용'), flush=True)


def qa_simulator(photo=None):
    record = RUNTIME / 'simulator.json'
    all_devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', '-j']))
    devices = [device for group in all_devices['devices'].values() for device in group]
    selected = json.loads(record.read_text()) if record.exists() else None
    device = next((d for d in devices if selected and d['udid'] == selected['udid'] and d['name'] == 'MOVID AI QA'), None)
    if device is None:
        runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes', '-j']))['runtimes']
        available = [r for r in runtimes if r.get('isAvailable') and r['name'].startswith('iOS')]
        if not available:
            raise RuntimeError('Xcode에 설치된 iOS Simulator 런타임이 필요합니다.')
        runtime = max(available, key=lambda r: tuple(int(v) for v in r['version'].split('.')))
        udid = subprocess.check_output(['xcrun', 'simctl', 'create', 'MOVID AI QA',
            'com.apple.CoreSimulator.SimDeviceType.iPhone-16', runtime['identifier']], text=True).strip()
        record.write_text(json.dumps({'udid': udid, 'runtime': runtime['identifier']}))
        device = {'udid': udid, 'state': 'Shutdown'}
    if device['state'] != 'Booted':
        subprocess.run(['xcrun', 'simctl', 'boot', device['udid']], check=True)
    subprocess.run(['xcrun', 'simctl', 'bootstatus', device['udid'], '-b'], check=True)
    if photo:
        subprocess.run(['xcrun', 'simctl', 'addmedia', device['udid'], str(Path(photo).resolve())], check=True)
    return device['udid']


def main():
    parser = argparse.ArgumentParser(description='원본 FE/BE를 수정하지 않는 로컬 Flutter AI 연결')
    parser.add_argument('--require-coach', action='store_true', help='Qwen3 준비를 먼저 확인하고 코치가 없으면 실행 중단')
    parser.add_argument('--no-app', action='store_true', help='인증·분석 서버만 실행')
    parser.add_argument('--photo', type=Path, help='전용 QA 시뮬레이터에 가져올 기존 사진')
    parser.add_argument('--device', help='명시적으로 선택할 Flutter 기기 ID; 기본은 별도 QA 시뮬레이터')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--backend-port', type=int, default=8082)
    parser.add_argument('--contour-model', type=Path, help='로컬 실험 윤곽 분류기 JSON; 생략하면 사진 측정만 실행')
    parser.add_argument('--geometry-only', action='store_true', help='DINOv3 인증 없이 측정 전용 브리지 데모')
    args = parser.parse_args()
    if args.geometry_only and args.contour_model:
        parser.error('--geometry-only와 --contour-model을 함께 사용할 수 없습니다.')
    if sys.version_info[:2] != (3, 12):
        raise RuntimeError('Python 3.12로 실행하세요.')
    if args.port == args.backend_port or not all(1 <= p <= 65535 for p in (args.port, args.backend_port)):
        raise RuntimeError('서로 다른 올바른 포트를 지정하세요.')
    for port in (args.port, args.backend_port):
        with socket.socket() as connection:
            if connection.connect_ex(('127.0.0.1', port)) == 0:
                raise RuntimeError(f'{port} 포트가 사용 중입니다. 기존 서버는 자동 종료하지 않습니다.')
    for tool in ('java', 'flutter' if not args.no_app else 'java'):
        if not shutil.which(tool):
            raise RuntimeError(f'{tool} 설치가 필요합니다.')
    integration = inspect_sources(ROOT.parent)
    for blocker in integration['blockers']:
        print('원본 앱 연결 확인: ' + blocker, flush=True)
    if not integration['backend'].get('email_verification_source_evidence'):
        print('새 회원가입 시연: 이메일 인증번호 API 근거가 없습니다. 실제 발송·확인 연결이 필요하며, 기존 시연 계정 로그인과 구분하세요.', flush=True)
    print('원본 FE/BE를 AI 실행 폴더에 동일하게 복사합니다.', flush=True)
    stage()
    env = dict(os.environ)
    classifier = None if args.geometry_only else args.contour_model or env.get('AI_CONTOUR_MODEL')
    mode_flags = ['--geometry-only'] if args.geometry_only else []
    if args.geometry_only:
        env.update(AI_DISABLE_DINO='1')
        env.pop('AI_REQUIRE_DINO', None)
        env.pop('AI_CONTOUR_MODEL', None)
    if classifier:
        classifier = Path(classifier).expanduser().resolve()
        if not classifier.is_file():
            raise RuntimeError('윤곽 분류기 파일을 찾을 수 없습니다: ' + str(classifier))
        env['AI_CONTOUR_MODEL'] = str(classifier)
        print('실험 윤곽 분류기: ' + str(classifier), flush=True)
    else:
        print('측정 전용 모드입니다.' if args.geometry_only else '윤곽 분류기 미지정: 사진 측정·특징 추출은 실행합니다.', flush=True)
    env.setdefault('MPLCONFIGDIR', str(ROOT / '.runtime/matplotlib'))
    env.setdefault('HF_HUB_CACHE', str(ROOT / '.cache/hub'))
    env.setdefault('GRADLE_USER_HOME', str(ROOT / '.cache/gradle'))
    env['XCODE_XCCONFIG_FILE'] = str(ROOT / 'bridge/ios-local.xcconfig')
    brew_java = Path('/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')
    if not env.get('JAVA_HOME') and brew_java.is_dir():
        env['JAVA_HOME'] = str(brew_java)
    subprocess.run(['bash', str(ROOT / 'run.sh'), '--install-only', *mode_flags], env=env, check=True)
    python = ROOT / '.venv/bin/python'
    check = [str(python), str(ROOT / 'scripts/check_environment.py'), '--model', *mode_flags]
    if classifier:
        check += ['--contour-model', str(classifier)]
    subprocess.run(check, cwd=ROOT, env=env, check=True)
    if not args.geometry_only:
        model = json.loads((ROOT / '.runtime/model.json').read_text())['path']
        env['DINO_MODEL_PATH'] = model
    if args.require_coach:
        subprocess.run([str(python), str(ROOT / 'scripts/check_coach.py')], cwd=ROOT, env=env, check=True)
    subprocess.run(['bash', str(RUNTIME / 'BE/gradlew'), '--project-dir', str(RUNTIME / 'BE'),
                    '--init-script', str(ROOT / 'bridge/spring-h2.init.gradle'), 'bootJar', '--no-daemon', '--console=plain'], env=env, check=True)
    auth_dir = RUNTIME / 'auth'
    auth_dir.mkdir(exist_ok=True, mode=0o700)
    key = auth_dir / 'jwt-secret'
    if not key.exists():
        key.write_text(secrets.token_urlsafe(48))
        key.chmod(0o600)
    env.update({'DB_URL': f'jdbc:h2:file:{auth_dir / "accounts"};MODE=MySQL;DATABASE_TO_LOWER=TRUE',
                'DB_USERNAME': 'sa', 'DB_PASSWORD': '',
                'SPRING_DATASOURCE_DRIVER_CLASS_NAME': 'org.h2.Driver',
                'SPRING_FLYWAY_ENABLED': 'false', 'SPRING_JPA_HIBERNATE_DDL_AUTO': 'update',
                'JWT_SECRET': key.read_text(), 'AI_BACKEND_URL': f'http://127.0.0.1:{args.backend_port}',
                'AI_BRIDGE_DIR': str(RUNTIME / 'bridge')})
    java = str(Path(env['JAVA_HOME']) / 'bin/java') if env.get('JAVA_HOME') else 'java'
    processes, logs = [], []
    try:
        backend_log = (RUNTIME / 'backend.log').open('a')
        logs.append(backend_log)
        backend = subprocess.Popen([java, '-jar', str(RUNTIME / 'BE/build/libs/BE-0.0.1-SNAPSHOT.jar'),
            '--server.address=127.0.0.1', f'--server.port={args.backend_port}'], cwd=RUNTIME / 'BE', env=env,
            stdout=backend_log, stderr=subprocess.STDOUT)
        processes.append(backend)
        wait_url(f'http://127.0.0.1:{args.backend_port}/actuator/health', backend)
        seed_account(f'http://127.0.0.1:{args.backend_port}', env.get('AI_DEMO_PASSWORD', 'movid1234'))
        ai_log = (RUNTIME / 'ai.log').open('a')
        logs.append(ai_log)
        ai = subprocess.Popen([str(python), '-m', 'uvicorn', 'app:app', '--host', '127.0.0.1', '--port', str(args.port)],
                              cwd=ROOT, env=env, stdout=ai_log, stderr=subprocess.STDOUT)
        processes.append(ai)
        wait_url(f'http://127.0.0.1:{args.port}/health', ai)
        print(f'Flutter 연결 API: http://127.0.0.1:{args.port}\n원본 소스 검사: {verify_originals()}개 동일\n로그: AI/.runtime/flutter_demo/', flush=True)
        coach_ready, coach_message = coach_readiness(f'http://127.0.0.1:{args.port}')
        print(coach_message, flush=True)
        print(f'사진 분석: http://127.0.0.1:{args.port}/analysis\n계정 코치: http://127.0.0.1:{args.port}/coach/account', flush=True)
        print('원본 Flutter 코치 탭은 별도 연결이 필요합니다. 계정 코치는 위 웹 주소를 사용하세요.', flush=True)
        print('AI 브리지 플랜·오늘의 플랜·세트 기록·달력 API를 제공합니다. 일반 운동 예시이며 원본 BE DB와 별도 저장합니다.', flush=True)
        if args.require_coach and not coach_ready:
            raise RuntimeError('필수 코치 준비 확인 실패. 시작한 서버를 종료합니다.')
        if args.no_app:
            print('서버 준비 완료. 종료: Ctrl+C', flush=True)
            while all(p.poll() is None for p in processes):
                time.sleep(1)
            return 1
        device = args.device or qa_simulator(args.photo)
        subprocess.run(['flutter', 'pub', 'get'], cwd=RUNTIME / 'FE', env=env, check=True)
        app = subprocess.Popen(['flutter', 'run', '-d', device, f'--dart-define=API_BASE_URL=http://127.0.0.1:{args.port}'],
                               cwd=RUNTIME / 'FE', env=env)
        processes.append(app)
        print('Simulator 또는 Xcode Device Hub에서 MOVID AI QA를 확인하세요. 원본 로그인·분석 화면을 사용합니다.', flush=True)
        return app.wait()
    except KeyboardInterrupt:
        return 0
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for stream in logs:
            stream.close()
        verify_originals()


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, ValueError, subprocess.CalledProcessError) as exc:
        raise SystemExit(str(exc))
