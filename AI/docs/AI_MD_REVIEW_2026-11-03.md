# AI.md 대응 결과 — 2026-11-03

사용자 제공 AI.md의 목록을 실제 AI 작업 트리에 대조했다. 변경은 AI 폴더에 한정하며 원본 FE·BE는 수정하지 않았다. 다운로드한 BE 스냅샷, 사진, DB, 실제 JSON, 로그는 비공개 AI/.runtime에만 보관한다.

## 항목별 처리

| 항목 | 처리 결과 |
|---|---|
| AI-1 | DINOv3 로딩 실패 시 측정 전용 모드. 특징 추출 및 응답 메타데이터의 null 접근 제거. `dinov3: null`. 윤곽 직접 분류는 503 MODEL_NOT_CONFIGURED. `AI_REQUIRE_DINO=1`이면 기존처럼 기동 실패 선택 가능. 실제 가중치 없는 경로와 실제 전신 사진으로 done 확인. |
| AI-2 | 기존 즉시 503 방식을 유지하고 호출자 직렬화·단일 워커·동시 요청 제한을 명시. 추론 중인 요청을 강제로 중단하거나 숨은 큐를 만들지 않음. |
| AI-3 | 공개 측면 reason을 SIDE_PHOTO_MISSING/LOW_CONFIDENCE로 정리. 상세 원인은 side_neck.diagnostic_reason에 분리. unavailable.key는 neck_forward_deg 유지. |
| AI-4 | requirements.txt에 requests 추가. 이미 직접 쓰던 Pillow도 명시. 전체 회귀 테스트에서 import 확인. 별도 새 venv 전체 설치까지 완료했다는 뜻은 아님. |
| AI-5 | DINOv3 또는 다중 포즈 자산 부재 시 health.status=degraded. 기능별 상태·frontal_check=false 표시. NOT_FRONTAL 자동 판정은 미구현으로 명시. 다중 인원 탐지의 실패 가능성을 실사진으로 확인했으며 기능을 보장하지 않음. |
| AI-6 | 입력·검증 오류의 사용자 메시지는 안전한 짧은 문자열 유지. enum·DB·FE error_message 표시는 공동 작업이므로 임의 변경하지 않음. 실제 받은 BE의 오류 메시지 DB 초과 실패를 별도 기록. |
| AI-7 | RequestValidationError 핸들러 추가. 기본 detail 배열 대신 detail 객체(code/message) 반환. 입력값·내부 경로를 노출하지 않음. |
| AI-8 | 브리지 성공과 실제 BE·MySQL 성공을 명확히 구분. 실제 원격 BE 스냅샷을 별도로 빌드해 MySQL과 검증. 아래 버전 한계 참고. |
| AI-9 | 레거시 debugImages에서 요청 종료 후 삭제되는 로컬 경로 제거. 빈 배열 반환. |
| AI-10 | 무인증 서버임을 명시. 기본 loopback 유지. 별도 머신은 BE만 접근 가능한 네트워크 제한 필요. 공유 키 도입은 BE와 동시 합의해야 하므로 일방적으로 인증 헤더를 요구하지 않음. |
| AI-11 | api-integration.md를 /v1/analyze, snake_case, 정면 1장, 선택 측면 1장 기준으로 재작성. 길이 제약·null·오류·책임 경계·Python 3.12를 명시. |
| AI-12 | 실제 DINOv3 서버에서 전신 사진 분석 및 실제 BE·MySQL 성공 경로 확인. AI 처리 약 0.98초, BE 분석 호출·조회 약 0.87초. 다른 장비·모든 입력에서 90초 이내를 보장하는 시험은 아님. |
| AI-13 | 모든 성공 judgement에 비어 있지 않은 label과 unit을 보장하는 회귀 검사 추가. 기존 코드도 이미 채우고 있었음. |

## 실제 실행 결과

- AI 실제 정면 요청 HTTP 200. unavailable.reason=SIDE_PHOTO_MISSING.
- 필드 누락 HTTP 422, detail={code:VALIDATION_FAILED,message:...}.
- 실제 가중치 없는 로컬 폴더로 기동한 엔진: 사진 측정 done, dinov3=null, 약 0.45초. 모델 부재가 더 이상 성공 측정을 500으로 만들지 않음.
- 실제 원격 BE → 수정된 AI → 격리 MySQL: 이메일 인증(외부 발송 비활성, 개발 로그에서 내부 확인), 가입, 로그인, 사진 업로드, 분석, 조회 및 SQL 저장 확인.
- MySQL 저장: done, pixel-dino-v2, 어깨 2.9°, 골반 3.1°, 측면 null. 실제 소수 반올림·길이 제약 내 저장 확인.
- 입력 1장 성공 경로는 확인했으나, 전체 운영 성능·다중 요청 부하·실제 Flutter UI를 검증한 것은 아님.
- 코드 자동 검사 133개 통과. FE·BE 원본 내용 723개 일치 검사와 AI-only 변경 범위 검사 수행.

## BE 버전 차이 및 미해결 공동 사항

원격 `Yubin-saves-the-world/Project`의 `fix/be-errors` 스냅샷은 사용자 문서에 서술된 BE 수정본과 일부 다르다. 문서의 170개 BE 테스트를 이 작업에서 재현했다고 주장하지 않는다. Downloads에서도 해당 새 Processor 클래스가 있는 로컬 수정본을 찾지 못했다.

받은 스냅샷에서 확인한 차이:

1. BodyAnalysisController가 기울기에서 점수를, 비율에서 체형을 자체 생성한다. AI는 둘 다 null을 반환한다. **BE가 만든 점수·체형은 AI가 검증한 판정이 아니다.**
2. 문서의 직렬 워커·90초 제한 구현과 다르게 동기 호출·기본 RestTemplate이 보인다.
3. 정상 사진의 실제 DB 저장은 통과했지만, 흐린 사진의 AI 오류를 BE가 긴 HTTP 예외 문자열로 저장하면서 `error_message` 길이를 초과해 HTTP 500이 발생했다. AI의 실제 오류 메시지는 100자 이하다. 정확한 최신 BE 수정본에서도 재확인이 필요하다. AI에서 이 오류를 성공으로 위장하지 않았다.

따라서 결과는 **정상 경로 성공, 오류 경로 포함 전체 통합은 미완료**다. 수정된 BE 커밋을 담당자가 확정한 후 같은 검사를 다시 수행해야 한다. 원본 BE 코드를 대신 고치지 않았다.

## 다중 인물 검사 한계

공식 공개 사진의 여러 전신 인물 장면을 실제 포즈 모델로 처리했으나 한 명만 검출해 HTTP 200을 반환한 사례가 있다. 자산이 로드됐다는 사실과 모든 다중 인물을 탐지한다는 주장은 다르다. 기존 테스트의 MULTIPLE_PEOPLE 거절 분기는 검증되지만 실제 모든 장면의 재현율을 보장하지 않는다. 사용자 1인 촬영 확인을 유지하고 독립 검증 전 보장 문구를 사용하지 않는다.

## 책임 결정

- 글 요약·목표 사진 요약·BE 목표 비교는 BE 담당 유지. AI analyze.goal_comparison=null.
- AI /v1/compare는 기하 차이 실험용 별도 도구이며 BE의 목표 비교와 중복 실행하지 않음.
- 외부 AI 전송 고지·동의, 오류 enum 확장·FE 표시, 공개 배포 인증은 담당자 공동 합의가 필요.
- 최근 실험 모델 v9와 운영 후보 v4의 학습·배포 상태는 이번 계약 수정으로 바꾸지 않음.

실제 응답과 검사 스크립트는 `.runtime/be_contract_20261103/`에 있다. 사진·로그·비밀번호·토큰·DB·모델·가상환경을 커밋하지 않는다.
