"""ZIP-friendly launcher. All project runtime files remain inside AI/."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import threading
import time
import urllib.request
import webbrowser

ROOT = Path(__file__).resolve().parents[1]


def dependency_digest():
    return hashlib.sha256(b''.join((ROOT / name).read_bytes() for name in (
        'requirements.txt', 'requirements-dinov3.txt', 'requirements-tested.lock.txt'))).hexdigest()


def open_when_ready(url, process):
    for _ in range(300):
        if process.poll() is not None:
            return
        try:
            with urllib.request.urlopen(url + '/health', timeout=1) as response:
                if response.status == 200:
                    webbrowser.open(url)
                    return
        except (OSError, ValueError):
            pass
        time.sleep(1)


def main():
    parser = argparse.ArgumentParser(description='MOVID AI 단독 실행')
    parser.add_argument('--port', type=int, default=int(os.environ.get('AI_PORT', '8001')))
    parser.add_argument('--no-browser', action='store_true')
    parser.add_argument('--install-only', action='store_true')
    args = parser.parse_args()
    if sys.version_info[:2] != (3, 12):
        raise SystemExit('Python 3.12로 실행하세요. 현재 버전: ' + sys.version.split()[0])
    if not 1 <= args.port <= 65535:
        raise SystemExit('포트는 1~65535 사이여야 합니다.')
    if not args.install_only:
        with socket.socket() as connection:
            if connection.connect_ex(('127.0.0.1', args.port)) == 0:
                raise SystemExit(f'{args.port} 포트가 사용 중입니다. 기존 서버를 확인하거나 --port로 변경하세요.')
    runtime = ROOT / '.runtime'
    runtime.mkdir(exist_ok=True)
    env = dict(os.environ)
    env.setdefault('MPLCONFIGDIR', str(runtime / 'matplotlib'))
    env.setdefault('HF_HUB_CACHE', str(ROOT / '.cache' / 'hub'))
    env.setdefault('PIP_CACHE_DIR', str(ROOT / '.cache' / 'pip'))
    python = ROOT / '.venv' / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    if not python.is_file():
        print('1/3 AI 전용 Python 환경을 만듭니다.', flush=True)
        subprocess.run([sys.executable, '-m', 'venv', str(ROOT / '.venv')], check=True)
    stamp = runtime / 'dependencies.sha256'
    digest = dependency_digest()
    if not stamp.is_file() or stamp.read_text() != digest:
        print('2/3 검증된 라이브러리를 설치합니다. 첫 실행에는 시간이 걸립니다.', flush=True)
        subprocess.run([str(python), '-m', 'pip', 'install', '-r', str(ROOT / 'requirements-dinov3.txt')],
                       cwd=ROOT, env=env, check=True)
        subprocess.run([str(python), str(ROOT / 'scripts' / 'check_environment.py')], cwd=ROOT, env=env, check=True)
        stamp.write_text(digest)
    if args.install_only:
        print('설치와 라이브러리 확인을 완료했습니다.', flush=True)
        return 0
    print('3/3 모델 접근을 확인합니다. 최초 실행에는 공식 가중치를 다운로드합니다.', flush=True)
    subprocess.run([str(python), str(ROOT / 'scripts' / 'check_environment.py'), '--model'],
                   cwd=ROOT, env=env, check=True)
    model = json.loads((runtime / 'model.json').read_text())
    env['DINO_MODEL_PATH'] = model['path']
    url = f'http://127.0.0.1:{args.port}'
    print(f'AI 서버 시작: {url}\n사진 테스트: {url}\nAPI 문서: {url}/docs\n종료: Ctrl+C', flush=True)
    process = subprocess.Popen([str(python), '-m', 'uvicorn', 'app:app', '--host', '127.0.0.1',
                                '--port', str(args.port)], cwd=ROOT, env=env)
    if not args.no_browser:
        threading.Thread(target=open_when_ready, args=(url, process), daemon=True).start()
    try:
        return process.wait()
    except KeyboardInterrupt:
        process.terminate()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError:
        raise SystemExit('실행 준비에 실패했습니다. 위 설치·모델 오류 안내를 확인하세요.')
