# 회원가입부터 AI 코치까지 — 10단계 시연 준비

2026-11-04. 수정 범위는 AI/뿐이다. 원본 Flutter·BE와 운영 DB를 변경하지 않았다.

## 단계별 현재 상태

| 순서 | 시연 | AI 측 준비와 남은 연결 |
|---|---|---|
| 1 | 닉네임·이메일·6자리 메일 인증·비밀번호 | **실제 메일 인증은 차단 항목.** 확인한 인증 서버 OpenAPI에 발송·확인 API가 없다. 고정 코드나 발송 성공을 가장하지 않는다. BE 담당 실제 이메일 전송·검증이 필요하다. |
| 2 | 약관 전체 동의 | 기존 Flutter·Spring 기능을 사용한다. 이번 작업에서 실제 신규 가입·약관 클릭을 검증하지 않았다. |
| 3 | 키·몸무게·나이·성별·목표·횟수 | 기존 프로필 API를 사용한다. 플랜 생성 시 본인 프로필의 성인 나이·목표·주간 횟수를 확인한다. |
| 4 | 정면·측면 업로드·분석 | 기존 비동기 사진 분석을 사용하며 실제 DINOv3로 확인했다. |
| 5 | 체형 측정 카드 | 각도·비율·측정 불가 사유를 제공한다. 측면 명칭은 ‘측면 귀·어깨 각도’. 건강·체형 점수는 null을 유지한다. |
| 6 | 날짜별 플랜·운동 상세 | 새 AI 브리지 API로 저장한다. 종목·세트·횟수·휴식·선정 이유를 기존 Flutter 모델 형식으로 제공한다. |
| 7 | 홈 오늘의 플랜 | GET /api/routines/today. 플랜 생성일을 첫 운동일로 배정해 당일 시연에서 확인할 수 있다. |
| 8 | 시작·세트 1~2개·완료 | 실제 서버 기록을 저장한다. 중복 시작·동일 세트 재전송·완료 재전송에 중복 기록을 만들지 않는다. |
| 9 | 달력 완료 날짜 | GET /api/workout-logs의 summary.workout_dates. 실제 완료 로그가 있는 날짜만 포함한다. |
| 10 | AI 코치 질문·답변 | 계정 대화 API·오늘 플랜 문맥·실제 Qwen3 응답을 확인했다. **main Flutter의 빈 코치 탭은 FE 연결 필요.** AI/bridge/flutter에 연결용 위젯과 테스트를 제공한다. |

따라서 **원본 앱 10단계 전체 완료 상태는 아니다.** 남은 주요 연결은 실제 메일 인증과 원본 Flutter 코치 화면이다. 이번 API 검증은 기존 시연 계정으로 수행했고 신규 가입 성공이나 실제 메일 수신을 주장하지 않는다.

## 실행과 검증

프로젝트 루트에서:

```bash
bash AI/run-flutter.sh --no-app --require-coach
```

앱을 실행하려면 `--no-app`을 빼고 원하는 기기를 지정한다. macOS의 예시는 `bash AI/run-flutter.sh --device macos --require-coach`다. Python 3.12, JDK 17 이상, Flutter 기기 실행 환경, 공식 DINOv3 승인·CLI 인증, Ollama의 로컬 qwen3 모델이 필요하다. `--geometry-only`는 DINOv3를 생략하며 관절 수치만 제공한다. 원본 FE·BE는 AI/.runtime으로 복사해 실행하고 생성 파일도 그 안에 둔다.

API 기본 주소는 실행기가 출력하는 주소다(기본 8080). 기존 Flutter가 **그 AI 브리지 주소**를 사용해야 새 플랜·기록 API를 읽는다. 원본 BE 포트에 직접 연결하면 AI에 추가한 API는 제공되지 않는다.

시연 4~10단계의 실제 API 연속 검사:

```bash
AI/.venv/bin/python AI/scripts/verify_demo_flow.py \
  --api http://127.0.0.1:8080 \
  --front "/정면/사진.jpg" --side "/측면/사진.jpg" --with-coach
```

기존 로컬 시연 계정 demo@movid.local을 사용하며 최초 비밀번호는 movid1234다. 변경한 비밀번호는 환경 변수 AI_DEMO_PASSWORD로 지정한다. 비밀번호·토큰은 결과에 출력하지 않는다. 검증 자료는 AI/.runtime/demo-flow에 저장한다. 기본적으로 이번 시험에서 새로 만든 사진과 운동 로그만 삭제한다. 플랜과 검사 중 생성된 코치 메시지는 남을 수 있다. 이미 진행 중인 운동을 발견하면 해당 기록을 덮어쓰지 않고 검사를 멈춘다.

`--keep-records`는 시연 입력 운동 기록을 보관한다. **자동 입력된 시연용 세트이지 실제 운동 수행을 검증한 기록이 아니다.** 기본 검사는 정리 후 달력 표시도 되돌아간다. 영상에서는 실제로 앱에서 세트를 입력·완료하면 해당 날짜가 남는다.

## 기본 플랜 구성 기준

- 본인의 완료 분석 ID가 필요하다. 사진 수치로 근육 부족·질환을 추론하지 않는다. 목표 사진 없이 생성할 수 있다.
- 성인 프로필의 목표와 주간 횟수(1~7)를 사용한다. 키·몸무게·성별로 과학적 처방을 한 것으로 표시하지 않는다.
- 오늘 또는 지정 시작일부터 7일 안에 주간 횟수만큼 배정한다. 상체·하체 기본 동작을 번갈아 배치하며 기본값은 종목당 1세트·5회·휴식 60초, 예상 10분이다. 시연용 시간·세트 구성이지 검증된 개인별 운동량이 아니다.
- 선정 이유는 ‘입력 목표와 주간 횟수에 따른 기본 예시’다. 사진에서 판단한 추천 우선 부위가 아니다. 미검증 점수를 근거로 만들지 않는다.
- 동작 안내는 [NHS의 일반 근력 운동 안내](https://www.nhs.uk/live-well/exercise/strength-exercises/)를 참고했다. 이 프로젝트의 세트·휴식·요일 구성을 NHS가 승인했다는 뜻은 아니다.
- 요청에 주의 항목이 있으면 CAUTION_REQUIRES_REVIEW로 보류한다. 기존 앱은 주의 항목을 수집하지 않으므로 누락을 ‘주의 없음 확인’으로 바꾸지 않고 cautions_status=not_collected로 반환한다.
- 재생성은 아직 시작하지 않은 플랜만 갱신한다. 기록이 있는 날짜는 예전 플랜과 기록을 보존하므로 변경한 주간 횟수보다 보존된 날짜가 많을 수 있다.

## API 요약

인증은 기존 Spring /api/users/me를 확인한다. 아래 데이터 저장소는 AI/.runtime의 SQLite이며 원본 BE MySQL과 자동 동기화하지 않는다.

| 요청 | 역할 |
|---|---|
| POST /api/routines | {analysis_id, start_date?:YYYY-MM-DD, cautions?:string[]} → {routines:[상세],source,saved,store,photo_measurements_used} |
| GET /api/routines/weekly?week_start=YYYY-MM-DD | 월요일부터 정확히 7일, 날짜별 요약·휴식 여부 |
| GET /api/routines/today | {date,is_rest_day,routine:상세 또는 null} |
| GET /api/routines/{id} | 제목·날짜·부위·상태·items(종목·세트·횟수·휴식·이유) |
| PATCH /api/routines/{id} | {status:planned 또는 skipped}. 완료 상태를 임의 지정하지 못함 |
| GET /api/exercises, GET /api/exercises/{id} | 시연 기본 동작 목록·상세. 번호 910001~910004 |
| POST /api/workout-logs | {exercise_id,routine_id?}. 신규 201·진행 중 재개 200 |
| GET /api/workout-logs/{id} | 실제 저장한 sets와 합계 |
| POST /api/workout-logs/{id}/sets | {client_set_id,set_no,weight_kg,reps,is_done,rest_sec?} |
| PATCH /api/workout-logs/{id}/sets/{set_id} | version 필수, 변경할 무게·횟수·완료·휴식 |
| DELETE /api/workout-logs/{id}/sets/{set_id} | 해당 세트 삭제 |
| PATCH /api/workout-logs/{id}/complete | {memo?}. 완료한 세트 1개 이상 필요 |
| GET /api/workout-logs?start_date=…&end_date=… | 날짜별 기록·summary.workout_dates. 조회 최대 92일 |
| DELETE /api/workout-logs/{id} | 본인 기록 삭제, 부속 세트와 완료 날짜·플랜 진행도에 반영 |
| GET·POST /api/ai-coach/messages | 계정 대화. POST {content}에 현재 계정의 오늘 플랜을 서버가 첨부 |

세트 범위: set_no 1~100, weight_kg 0~500의 유한 숫자, reps 1~100, rest_sec 0~3600, is_done 엄격한 boolean. 숫자 문자열·true를 숫자로 바꾸지 않는다. 무게 0은 맨몸 운동 기록이며 체중을 임의로 곱하지 않는다. total_volume_kg는 완료 세트의 weight_kg×reps 합계다. 세트 권장 목표와 실제 기록 개수는 별개다.

종목 로그 하나를 완료하면 달력에 그 날짜가 포함된다. 플랜의 모든 종목을 완료해야 플랜 status=done이다. 완료 기록의 마지막 완료 세트를 없애려면 기록 전체 삭제를 사용한다. 이중 수정은 VERSION_CONFLICT(409), 같은 client_set_id에 다른 값은 IDEMPOTENCY_CONFLICT(409), 6시간 지난 진행은 WORKOUT_EXPIRED(409)다. 새 시작 시 지난 진행을 aborted로 보존한다. 다른 계정의 플랜·로그·세트에는 404를 반환한다.

## 실제 JSON과 검증 범위

[예시 응답 폴더](api-contract/demo-flow/)에 실제 로컬 API 응답을 제공한다. 테스트 계정의 **시연 입력**이며 원본 사진·특징 벡터·토큰은 포함하지 않는다. 날짜와 ID는 예시 값이므로 클라이언트가 고정하지 않는다.

실제 DINOv3 정면+측면 분석 → 플랜 저장 → 홈 조회 → 종목별 세트 2개 입력 → 완료 → 달력 → 저장 플랜 코치 → Qwen3 생성을 확인했다. main과 내용이 같은 Flutter 모델로 실제 응답 파싱 테스트 2개, AI 소유 코치 위젯 테스트 3개도 통과했다. 원본 전체 앱을 신규 회원가입부터 클릭한 테스트는 아니며 실제 이메일·빈 코치 탭의 연결은 위 차단 항목대로 남아 있다.
