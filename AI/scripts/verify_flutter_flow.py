"""Exercise real local login/upload/poll/result, without storing tokens or photos."""
import argparse
import json
import math
import os
from pathlib import Path
import sys
import time
from urllib.parse import urlparse

import requests

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.dataset import local_api, write_json


def validate_result(result):
    if result.get('status') != 'done':
        raise ValueError('사진 분석이 완료되지 않았습니다.')
    measures = result.get('measures') or {}
    required = ('shoulder_tilt_deg', 'pelvis_tilt_deg', 'shoulder_hip_ratio', 'torso_leg_ratio')
    for key in required:
        value = measures.get(key)
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError('필수 측정값이 없거나 올바르지 않습니다: ' + key)
    return {key: measures[key] for key in required}


def verify(base, photo, password, report_path):
    base = local_api(base)
    parsed = urlparse(base)
    if parsed.path not in ('', '/') or parsed.query or parsed.fragment:
        raise ValueError('API 주소는 경로·쿼리가 없는 로컬 서버 주소여야 합니다.')
    photo = Path(photo)
    if not photo.is_file() or photo.stat().st_size > 10 * 1024 * 1024:
        raise ValueError('실제 10MB 이하 JPG/PNG 사진 경로가 필요합니다.')
    session = requests.Session()
    session.trust_env = False  # Never send local photos through an environment proxy.
    def request(method, path, **kwargs):
        response = session.request(method, base + path, timeout=20,
                                   allow_redirects=False, **kwargs)
        if 300 <= response.status_code < 400:
            raise ValueError('로컬 API 리디렉션을 거부했습니다.')
        if not response.ok:
            raise ValueError(f'연결 검사 실패: {method} {path} HTTP {response.status_code}')
        return response.json() if response.content else None
    photo_id, completed = None, False
    report = {'status': 'failed', 'checks': [], 'photo_cleanup': 'not_uploaded'}
    try:
        health = request('GET', '/health')
        if health.get('status') != 'ok' or not health.get('dinov3_loaded'):
            raise ValueError('AI 모델이 준비되지 않았습니다.')
        report['checks'].append('model_health')
        login = request('POST', '/api/auth/login', json={
            'email': 'demo@movid.local', 'password': password})
        session.headers['Authorization'] = 'Bearer ' + login['access_token']
        report['checks'].append('spring_login')
        with photo.open('rb') as stream:
            uploaded = request('POST', '/api/photos', files={'image': (photo.name, stream)},
                               data={'type': 'current', 'side': 'front'})
        photo_id = uploaded['photo_id']
        report['checks'].append('photo_upload')
        ticket = request('POST', '/api/body-analyses/photo', json={'photo_id': photo_id})
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            result = request('GET', '/api/body-analyses/' + str(ticket['analysis_id']))
            if result['status'] != 'pending':
                completed = True
                break
            time.sleep(1)
        else:
            raise ValueError('분석 결과 대기 시간이 초과됐습니다.')
        report['measures'] = validate_result(result)
        report.update(status='passed', measurement_version=result.get('measurement_version'),
                      contour_model=health.get('contour_model'),
                      scope='HTTP flow used by Flutter; not a UI or camera test')
        report['checks'].append('analysis_result')
        return report
    finally:
        if photo_id is not None:
            report['photo_cleanup'] = 'pending_analysis_not_deleted'
            if completed:
                try:
                    request('DELETE', '/api/photos/' + str(photo_id))
                    report['photo_cleanup'] = 'deleted_test_upload'
                except (ValueError, requests.RequestException):
                    report['photo_cleanup'] = 'cleanup_failed'
        session.close()
        write_json(report_path, report)


def main():
    parser = argparse.ArgumentParser(description='Flutter용 로컬 로그인·사진 분석 연결 검사')
    parser.add_argument('--api', default='http://127.0.0.1:8080')
    parser.add_argument('--photo', required=True, type=Path)
    parser.add_argument('--report', type=Path, default=ROOT/'.runtime/flutter-flow-check.json')
    args = parser.parse_args()
    report_path = args.report.resolve()
    if not report_path.is_relative_to(ROOT/'.runtime'):
        raise ValueError('검사 보고서는 AI/.runtime 내부에 저장하세요.')
    result = verify(args.api, args.photo, os.environ.get('AI_DEMO_PASSWORD', 'movid1234'), report_path)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, requests.RequestException, KeyError) as exc:
        raise SystemExit('연결 검사 실패: ' + str(exc))
