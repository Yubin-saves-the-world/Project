"""Run the demo's real AI HTTP chain. Uses explicit simulated set inputs.

Does not send email, fabricate verification codes, or claim Flutter UI coverage.
"""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import sys
import time
from urllib.parse import urlparse
from zoneinfo import ZoneInfo

import requests

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.dataset import local_api
from scripts.verify_flutter_flow import validate_result


def verify(base, front, side, password, output, *, with_coach=False, keep_records=False):
    base = local_api(base).rstrip('/')
    parsed = urlparse(base)
    if parsed.path or parsed.query or parsed.fragment:
        raise ValueError('경로 없는 로컬 API 주소를 사용하세요.')
    output = Path(output).resolve()
    if not output.is_relative_to(ROOT / '.runtime'):
        raise ValueError('검증 자료는 AI/.runtime 안에만 저장합니다.')
    for path in (front, side):
        if path and (not Path(path).is_file() or Path(path).stat().st_size > 10*1024*1024):
            raise ValueError('10MB 이하 로컬 JPG/PNG 사진이 필요합니다.')
    output.mkdir(parents=True, exist_ok=True)
    report = {'status': 'failed', 'checks': [], 'ui_verified': False,
              'signup_email_verified': False, 'sets_are_demo_inputs': True, 'keep_records': keep_records}
    uploads, own_logs = [], []

    def save(name, value):
        (output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')

    with requests.Session() as session:
        session.trust_env = False
        def call(method, path, **kwargs):
            response = session.request(method, base + path, timeout=120, allow_redirects=False, **kwargs)
            if not response.ok or 300 <= response.status_code < 400:
                raise ValueError(f'{method} {path} HTTP {response.status_code}')
            return (response.json() if response.content else None), response.status_code

        try:
            login, _ = call('POST', '/api/auth/login', json={'email':'demo@movid.local','password':password})
            session.headers['Authorization'] = 'Bearer ' + login['access_token']
            report['checks'].append('existing_demo_account_login')
            for position, image in (('front', front), ('side', side)):
                if image:
                    path = Path(image)
                    with path.open('rb') as stream:
                        photo, _ = call('POST', '/api/photos', files={'image':(path.name, stream, 'application/octet-stream')},
                            data={'type':'current','side':position})
                    uploads.append(photo['photo_id'])
            ticket, _ = call('POST', '/api/body-analyses/photo', json={
                'photo_id':uploads[0], 'side_photo_id':uploads[1] if len(uploads)>1 else None})
            deadline = time.monotonic() + 100
            while time.monotonic() < deadline:
                analysis, _ = call('GET', f"/api/body-analyses/{ticket['analysis_id']}")
                if analysis['status'] != 'pending':break
                time.sleep(1)
            validate_result(analysis)
            if side and analysis['measures'].get('neck_forward_deg') is None:
                raise ValueError('이 사진의 측면 귀·어깨 각도가 계산되지 않았습니다.')
            save('analysis.json', analysis)
            report['checks'].append('front_side_measurement' if side else 'front_measurement')
            plans, _ = call('POST', '/api/routines', json={'analysis_id':analysis['analysis_id']})
            assert plans['routines'], 'No saved plan'
            save('routines.json', plans)
            report['checks'].append('saved_dated_routines')
            home, _ = call('GET', '/api/routines/today')
            assert home['routine'] is not None, 'Today plan missing'
            save('today.json', home)
            selected = home['routine']
            detail, _ = call('GET', f"/api/routines/{selected['routine_id']}")
            save('routine-detail.json', detail)
            report['checks'].append('routine_detail_and_home')
            for item in selected['items']:
                log, status = call('POST', '/api/workout-logs', json={
                    'routine_id':selected['routine_id'],'exercise_id':item['exercise']['exercise_id']})
                if status != 201:
                    raise ValueError('기존 진행 중 운동을 보호하기 위해 검증을 중단합니다. 기존 기록을 먼저 확인하세요.')
                lid = log['log_id'];own_logs.append(lid)
                for number in (1, 2):
                    call('POST', f'/api/workout-logs/{lid}/sets', json={
                        'client_set_id':f'demo-{lid}-{number}', 'set_no':number,
                        'weight_kg':0, 'reps':5, 'is_done':True, 'rest_sec':60})
                completed, _ = call('PATCH', f'/api/workout-logs/{lid}/complete', json={'memo':'시연용 입력 · 실제 운동 수행 검증 아님'})
                assert completed['set_count'] == 2
                assert completed['total_volume_kg'] == 0
                save(f'completed-{lid}.json', completed)
            assert completed['routine_status'] == 'done', 'Routine progress did not complete'
            report['checks'].append('two_sets_per_exercise_and_completion')
            key = datetime.now(ZoneInfo('Asia/Seoul')).date().isoformat()
            calendar, _ = call('GET', f'/api/workout-logs?start_date={key}&end_date={key}&status=completed')
            assert key in calendar['summary']['workout_dates'], 'Calendar date missing'
            assert {log['log_id'] for log in calendar['items']} >= set(own_logs)
            save('calendar.json', calendar)
            report['checks'].append('calendar_from_actual_saved_logs')
            saved, _ = call('POST', '/api/ai-coach/messages', json={'content':'오늘 플랜의 세트와 휴식 시간을 알려주세요.'})
            assert saved['context']['saved_routine_id'] == selected['routine_id']
            assert saved['assistant_message']['response_source'] == 'rule_based_saved_routine'
            save('coach-saved-plan.json', saved)
            report['checks'].append('coach_reads_owned_saved_plan')
            if with_coach:
                reply, _ = call('POST', '/api/ai-coach/messages', json={'content':'꾸준히 운동하는 습관을 만드는 팁을 짧게 알려주세요.'})
                assert reply['assistant_message']['model'], 'Qwen3 model response missing'
                save('coach-qwen.json', reply)
                report['checks'].append('real_qwen3_reply')
            report['status'] = 'passed'
        finally:
            cleanup_failures = []
            for lid in own_logs if not keep_records else []:
                try:call('DELETE', f'/api/workout-logs/{lid}')
                except (ValueError, requests.RequestException):cleanup_failures.append(f'log:{lid}')
            for pid in uploads:
                try:call('DELETE', f'/api/photos/{pid}')
                except (ValueError, requests.RequestException):cleanup_failures.append(f'photo:{pid}')
            report['cleanup_pending'] = cleanup_failures
            save('report.json', report)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='시연 4~10단계의 실제 로컬 AI API 검증 · 가입 이메일·화면 클릭 검증 아님')
    parser.add_argument('--api', default='http://127.0.0.1:8080')
    parser.add_argument('--front', type=Path, required=True)
    parser.add_argument('--side', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT/'.runtime/demo-flow')
    parser.add_argument('--with-coach', action='store_true')
    parser.add_argument('--keep-records', action='store_true', help='명시적인 시연 입력 기록을 보관. 기본값은 이번에 만든 운동 기록 삭제')
    args = parser.parse_args()
    try:
        result = verify(args.api, args.front, args.side, os.environ.get('AI_DEMO_PASSWORD','movid1234'),
            args.output, with_coach=args.with_coach, keep_records=args.keep_records)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (ValueError, AssertionError, requests.RequestException, KeyError) as exc:
        raise SystemExit('시연 API 검증 실패: ' + str(exc))
