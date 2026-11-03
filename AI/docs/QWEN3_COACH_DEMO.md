# Qwen3 코치 시연

2026-11-03. AI 폴더 안에 로컬 Qwen3 대화 API와 시연 화면을 구현했다. 원본 Flutter·BE는 수정하지 않았다. **원본 앱의 코치 탭 연결 완료와 구분한다.**

## 실행

이 컴퓨터에는 Ollama와 qwen3:4b(약 2.5GB)가 이미 있다. 추가 가중치 다운로드 없이 사용했다. 다른 컴퓨터는 먼저 Ollama 공식 배포판과 모델을 준비한다.

```bash
# Ollama가 실행 중이지 않을 때 별도 터미널에서 실행
ollama serve
# 모델이 없는 컴퓨터에서만 준비
ollama pull qwen3:4b

# 아래 명령은 프로젝트의 AI 폴더에서 실행
.venv/bin/python scripts/check_coach.py
# 이 컴퓨터처럼 사진 모델까지 준비된 환경
bash run-coach.sh
# DINOv3 승인 없이 사진 측정+코치만 실행할 경우
# bash run-coach.sh --geometry-only
```

화면: http://127.0.0.1:8023/coach

기존 사진 특징 추출도 함께 쓰려면 승인된 Hugging Face 계정과 모델 준비 후 `--geometry-only`를 빼고 실행한다. 코치 자체는 Hugging Face 토큰이나 외부 API 키가 필요 없다. Ollama 설정은 컴퓨터 전역에서 바꾸지 않았다. `AI_COACH_URL` 기본값은 http://127.0.0.1:11434이며 로컬 HTTP 주소만 허용한다. 기본 모델은 `AI_COACH_MODEL=qwen3:4b`다. 임의 클라우드 모델로 전환하거나 외부 API로 대체하지 않는다.

## 시연 순서

1. AI 코치 화면의 Qwen3 준비 상태를 확인한다.
2. 목표·경험·주당 횟수·시간을 선택한다.
3. “운동을 처음 시작해요. 주 3회 20분 계획을 알려주세요.”라고 질문한다.
4. 표시된 시간표 합계와 Qwen3의 실행 팁을 확인한다.
5. “방금 계획을 10분으로 줄여 주세요.”라고 후속 질문한다.
6. 필요하면 사진 분석 화면에서 실제 사진을 분석하고 수치를 저장한 뒤 코치로 돌아와 수치 참고를 직접 선택한다. 사진·상완 크롭은 코치 모델에 보내지 않는다.
7. 새 대화 버튼으로 초기화한다. 새로고침 시 대화는 사라진다.

시간표는 서버의 **규칙 기반 일반 예시**이고 Qwen3 답변은 실행 팁·설명이다. 둘을 구분해서 표시한다. 사진의 정상·이상 또는 통증 관련 요청에는 **규칙 기반 안내 원칙**을 표시하고 Qwen3 생성 답변이라고 표기하지 않는다. 개인별 적합성을 검증한 처방이나 BE에 저장한 실제 루틴이 아니다.

## BE 전달 계약

`POST /v1/coach/chat`, application/json:

```json
{
  "messages": [
    {"role":"user","content":"운동을 꾸준히 하는 방법을 알려주세요."}
  ],
  "profile": {"goal":"habit","experience":"beginner","weekly_days":3,"minutes":20},
  "measurements": null
}
```

- messages는 사용자·assistant를 번갈아 전달하고 사용자로 시작·종료한다. system 역할은 받지 않는다.
- 최대 15개, 항목당 2,000자, 전체 UTF-8 6,000바이트. 화면은 오래된 대화부터 쌍으로 줄여 전송한다.
- profile.goal: habit/strength/mobility. experience: beginner/intermediate.
- measurements는 사용자가 참고를 선택한 경우에만 다섯 측정값을 전달한다. shoulder_tilt_deg, pelvis_tilt_deg, neck_forward_deg, shoulder_hip_ratio, torso_leg_ratio. 사진·진단·건강 점수는 받지 않는다.
- 성공: status=done, message.role=assistant, message.content, model, provider, response_source, plan, processing_seconds, context_used, conversation_storage=none.
- response_source=model_generated이면 실제 Qwen3가 생성했다. model_generated_filtered는 생성 답변의 일부 단정 문장을 제거한 경우이며 filtered_sentences로 표시한다. rule_based_scope_guidance는 안내 원칙이며 model=null이다.
- plan.source=rule_based_example은 시간 합계를 서버가 맞춘 시연용 일반 예시다. 모델 생성·의료적 검증·루틴 저장 성공을 뜻하지 않는다.
- 모델 점수·체형 등급을 만들지 않는다. Qwen3 원시 응답·내부 추론은 표시하지 않는다.
- 상태 확인: GET /v1/coach/health → ready/model_missing/offline/misconfigured. ready는 설치된 모델 조회이며 응답 품질 보장은 아니다.

오류 형식은 `{detail:{code,message}}`다. 422 VALIDATION_FAILED, 503 COACH_NOT_CONFIGURED/COACH_OFFLINE/COACH_MODEL_MISSING/COACH_BUSY/COACH_UNAVAILABLE, 504 COACH_TIMEOUT, 502 COACH_INVALID_RESPONSE/COACH_SCOPE_VIOLATION을 구분한다. 모델 장애 때 고정 답변을 모델 답변으로 위장하지 않는다. 모델 출력이 규칙을 위반하면 표시하지 않으며 재질문 안내를 제공한다.

BE는 인증·대화 ID·대화 이력 저장을 담당하고 AI에 필요한 대화 창만 전달하도록 연결하면 된다. 원본 BE의 Anthropic 코치·키워드 대체 응답을 이 API와 동시에 호출하면 안 된다. 기존 `/api/...` 경로를 AI에서 가로채거나 BE 코드를 수정하지 않았다.

## 한계와 운영 주의

- 대화는 화면 메모리와 요청 처리 중에만 유지하며 자동 DB 저장·파일 로그를 만들지 않는다. 시연 검증을 위해 만든 일반 질문·응답 예시는 비공개 .runtime에만 있다. 원시 측정 수치 기록은 별도 브라우저 저장 기능이다.
- 루틴 예시는 합계와 횟수만 코드로 검증했다. 개인별 의학적 적합성을 검증한 운동 처방이 아니다.
- 작은 로컬 모델이라 응답 품질과 지연이 일정하지 않다. 패턴 기반 출력 검사도 모든 부정확한 답변을 검출하지 못한다.
- 기존 Ollama 템플릿에서 내부 추론 출력·언어 문제가 재현돼 구조화된 JSON reply로 최종 답변을 받도록 했다. 파싱 실패·추론 태그·한국어 형식 불일치·일부 미검증 판정을 차단한다. 내부 추론이 전혀 생성되지 않는다고 보장하지 않는다.
- 코치는 동시 한 건만 생성한다. 사진 추론과 별도 제한이며 코치 중복은 COACH_BUSY다.
- 인증 없는 로컬 시연 API다. 공개 배포에는 BE 인증·접근 제한·사용량 제한·로그 정책 검토가 필요하다.
- 이번 시연 화면은 AI 웹 UI다. Flutter 코치 화면과 실제 BE 대화 저장까지 완료했다고 발표하지 않는다.

계획 요청에서는 서버가 최근 요청·설정으로 시간표를 만들고, 모델에는 목표·경험에 맞춘 실행 팁만 별도로 요청한다(history_used=false, context_used=false). 일반 대화는 전달한 대화 창을 사용한다(history_used=true). 의료적 판정·통증 안내는 model=null인 규칙 기반 안내다. 이를 모두 모델이 생성한 답변이라고 설명하지 않는다.

계획은 유효하지만 모델의 추가 팁이 표시 기준을 만족하지 못하면, response_source=rule_based_plan, model=null, model_tips_status=omitted로 시간표만 명확히 표시한다. 이를 Qwen3 답변으로 표기하지 않는다. 모델 연결 실패·시간 초과는 여전히 오류이며 모델 답변을 고정 문장으로 대체하지 않는다.

## 받은 BE 스냅샷 기준 연결 지점

`AiCoachController.generateReply()`의 Anthropic 호출·키워드 대체 분기 대신 AI의 `/v1/coach/chat`을 호출하는 변경이 BE에 필요하다. BE가 가진 사용자/assistant 이력에서 최근 대화를 시간순으로 가져와 마지막 사용자 입력을 붙인다. AI 제한(최대 15개·UTF-8 6000바이트)에 맞춰 오래된 쌍부터 줄인다. 원시 체형 점수·body_type을 프롬프트에 넣지 말고 허용된 측정값만 선택적으로 전달한다.

응답의 `message.content`를 assistant 메시지로 저장한다. plan이 있으면 규칙 기반 예시라는 출처와 합계·단계를 별도로 전달하거나, 기존 문자열 UI라면 출처를 명시한 텍스트로 함께 조합해야 한다. source가 규칙 기반이면 Qwen3 답변이라고 표시하지 않는다. AI 호출 실패를 고정 답변으로 숨기지 않고 저장·재시도 정책을 정한다. 이 파일에서 BE 코드를 수정한 것은 아니다.

공식 참고: [Ollama Chat API](https://docs.ollama.com/api/chat), [Qwen3 4B](https://ollama.com/library/qwen3:4b).
