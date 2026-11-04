"""Read-only source check. Evidence of wiring is not proof of runtime success."""
from pathlib import Path
import argparse
import json

ROOT = Path(__file__).resolve().parents[1]


def inspect_sources(repo):
    repo = Path(repo)
    shell = repo / 'FE/lib/app/shell/main_shell.dart'
    placeholder = None
    if shell.is_file():
        text = shell.read_text(encoding='utf-8')
        position = text.find("title: '인공지능 코치'")
        if position >= 0:
            placeholder = 'EmptyView(' in text[position:position + 250]
    java_root = repo / 'BE/src/main/java'
    calls = []
    controllers = []
    email_endpoints = []
    for path in sorted(java_root.rglob('*.java')) if java_root.is_dir() else []:
        text = path.read_text(encoding='utf-8')
        if 'class AiCoachController' in text:
            controllers.append(str(path.relative_to(repo)))
        if '/v1/chat' in text and ('COACH_SERVER_URL' in text or 'coach.server' in text):
            calls.append(str(path.relative_to(repo)))
        if 'email-verifications' in text and '@PostMapping' in text:
            email_endpoints.append(str(path.relative_to(repo)))
    blockers = []
    if placeholder is True:
        blockers.append('원본 Flutter 코치 탭이 빈 화면입니다. FE 담당 화면 연결이 필요합니다.')
    elif placeholder is None:
        blockers.append('원본 Flutter 코치 탭을 소스에서 확인하지 못했습니다.')
    if not calls:
        blockers.append('BE 소스에서 로컬 /v1/chat 호출과 주소 설정 근거를 찾지 못했습니다. 환경 변수만으로 연결된다고 판단하지 마세요.')
    return {
        'check_type': 'source_evidence_only',
        'status': 'blocked' if blockers else 'runtime_verification_required',
        'frontend': {'coach_placeholder_detected': placeholder},
        'backend': {'coach_controllers': controllers, 'local_coach_call_evidence': calls,
                    'email_verification_source_evidence': email_endpoints,
                    'actual_email_delivery_verified': False},
        'blockers': blockers,
        'ai_web_alternative': '/coach/account',
        'note': '소스 문자열 점검이며 앱·BE·모델을 실행하거나 파일을 수정하지 않습니다. 근거가 있어도 종단 실행 검증은 별도입니다.',
    }


def main():
    parser = argparse.ArgumentParser(description='원본 Flutter·BE 코치 연결 근거를 읽기 전용으로 확인')
    parser.add_argument('--repo', type=Path, default=ROOT.parent)
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--strict', action='store_true', help='차단 항목이 있으면 종료 코드 1')
    args = parser.parse_args()
    result = inspect_sources(args.repo)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print('원본 앱 코치 연결: ' + result['status'])
        for blocker in result['blockers']:
            print('- ' + blocker)
        print('AI 웹 코치: 실행 중인 AI 호환 서버의 /coach/account')
    return 1 if args.strict and result['blockers'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
