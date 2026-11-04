# AI 수정 내역 적용 결과 및 BE 코치 계약

사용자 제공 `AI_수정내역.md`(2026-11-03, 기준 12d1c25)를 현재 AI 코드와 대조했다. FE/BE는 수정하지 않았다.

## 항목별 적용

| 문서 항목 | 현재 처리 |
|---|---|
| 1. DINOv3 없는 health | 기존 반영: dinov3_loaded=false, device=null, status=degraded |
| 2. 모델 실패 시 서버 기동 | 기존 반영: 측정 전용으로 기동. AI_REQUIRE_DINO=1이면 명시적으로 실패 |
| 3. 특징 추출 조건 실행 | 기존 반영: 모델이 있을 때만 추출 |
| 4. 결과 조립부 None 참조 | 기존 반영: dinov3=null. 모델 없는 analyze 성공 회귀 테스트 유지 |
| 5. 윤곽 분류 방어 | 기존 반영: DINOv3 또는 분류기 없으면 503 MODEL_NOT_CONFIGURED |
| 6. requests 의존성 | 기존 반영: requirements.txt에서 직접 선언, lock 제약으로 검증 버전 사용 |
| 7. BE용 로컬 코치 | 이번 추가: POST /v1/chat, 기존 로컬 Qwen3 코치 재사용 |
| 8. 사유 코드·판정·상태 | 기존 반영: 공개 사유 코드 통일, 상세 원인은 diagnostic_reason. 점수·체형 판정은 미제공 |

기존 `test_be_contract_hardening.py`가 모델 미로드 분석 성공·상태·윤곽 방어·사유 코드를 검증한다. 제안된 별도 1.7B 모델은 새로 설치하지 않았다. 현재 모델은 기본 `qwen3:4b`이며 `AI_COACH_MODEL`로 로컬 qwen3 태그를 선택한다. `COACH_MODEL=Qwen/...` 방식은 사용하지 않는다. 실제 응답의 model 필드가 실행 모델을 나타낸다.

## BE 요청·응답

AI 서버의 `POST /v1/chat`:

```json
{
  "system": "회원 정보, 최근 분석, 오늘 루틴 등 서버가 제공하는 문맥",
  "messages": [{"role": "user", "content": "오늘 루틴을 시작하는 팁을 알려주세요."}],
  "max_new_tokens": 300
}
```

응답 형식(아래 내용·시간은 형식 설명용):

```json
{
  "reply": "질문에 대한 한국어 답변",
  "model": "qwen3:4b",
  "seconds": 8.3,
  "response_source": "model_generated",
  "truncated": false
}
```

- system: 생략 가능, 최대 6000자. 서버 문맥은 기본 코치 지침 아래의 데이터로 전달한다. 코치의 진단 제한 등을 덮어쓰는 지침으로 취급하지 않는다.
- messages: 1~20개, 각 1~2000자, user/assistant 교대, 마지막 user. 잘린 기록의 첫 assistant도 허용한다.
- system과 모든 메시지는 UTF-8 합계 12000바이트 이하. 제어 토큰과 빈 메시지는 거절한다.
- max_new_tokens: 엄격한 정수 32~512, 기본 300. 생성 상한이며 답변 길이를 보장하지 않는다.
- 이 경로는 BE가 제공한 오늘 루틴 등 문맥을 모델에 전달한다. 웹 시연용 기본 시간표를 생성해 덧붙이지 않는다.
- 정책 안내 응답은 model=null, response_source=rule_based_scope_guidance로 반환할 수 있다. 모델 답변으로 가장하지 않는다.
- 대화를 이 경로에서 자동 저장하지 않는다. BE가 대화 저장을 담당한다.
- 실패 형식: `{"detail":{"code":"COACH_TIMEOUT","message":"..."}}`. 입력 422, 모델 미설정·연결 실패·혼잡 503, 응답 형식 오류 502, 시간 초과 504. 고정 답변을 성공 응답으로 반환하지 않는다.

## 실행과 연결

BE에 `/v1/chat` 호출 코드가 구현돼 있는 경우에만 `COACH_SERVER_URL` 등의 주소 설정이 의미가 있다. 2026-11-04 확인한 main(2892c4a)에는 코치 컨트롤러가 없고, fix/be-errors(041ee64)는 Anthropic·고정 답변 분기이며 이 환경 변수를 읽지 않는다. 따라서 현재 원격 소스에는 BE 담당자가 로컬 코치 호출 코드를 먼저 연결해야 한다. 주소 예시는 AI 서버가 8001인 경우 `http://127.0.0.1:8001`이다. AI API 구현만으로 BE 연결이 끝났다고 판단하지 않는다. 이번 작업은 BE 코드를 변경하지 않았다.

코치 시연을 8100에서 따로 열고 DINOv3 다운로드를 생략하려면 프로젝트 루트에서:

```bash
bash AI/run-coach.sh --geometry-only --port 8100
```

이 명령도 기존 AI 앱을 실행한다. Python 의존성 및 포즈 모델 준비가 필요하며 Ollama와 로컬 Qwen3 모델은 미리 준비해야 한다. 새로운 Hugging Face 코치 모델은 내려받지 않는다.

코치 준비 여부는 `GET /v1/coach/health`를 확인한다. `GET /health`는 사진 엔진 상태이며 측정 전용 모드에서 degraded일 수 있다. 코치와 사진 준비 상태를 혼동하지 않는다. 모델 준비 후 첫 생성은 후속 호출보다 오래 걸릴 수 있다. 자동 워밍업으로 기동 시간을 늘리지 않으며 `AI/.venv/bin/python AI/scripts/check_coach.py --smoke`로 실제 첫 호출을 명시적으로 확인할 수 있다.

원본 Flutter 코치 화면 연결과 실제 BE 프로세스의 COACH_SERVER_URL 설정은 담당 영역 작업이다. AI API 추가만으로 정적 Flutter 화면이 대화 화면으로 변경되지는 않는다.

## 검증 및 제한

전체 자동 테스트 163개 통과 및 로컬 Qwen3 실제 `/v1/chat` 요청·응답을 확인했다. BE 프로세스를 새 환경 변수로 재실행한 종단 검증은 이번 범위에 포함하지 않았다. 원문 출력에서 발견한 통증 후 재시작 권유·임의 신체 치수 조건·빈 목록 번호를 제외하는 회귀 검사를 추가했다. 이 검사는 모델의 모든 잘못된 설명이나 운동 적합성을 보장하지 않는다. 생성 답변은 실험적 일반 안내이며 사용자별 운동 처방으로 평가하지 않았다. 모델·토큰·개인 기록은 추가로 저장소에 포함하지 않았다.


원본 코드 연결 근거 점검: `python3 AI/scripts/check_team_integration.py --json`. 문자열 근거를 읽는 보조 점검이며 실제 연결 성공 판정은 아니다. Flutter 실행 도구도 이 차단 항목을 출력한다.
