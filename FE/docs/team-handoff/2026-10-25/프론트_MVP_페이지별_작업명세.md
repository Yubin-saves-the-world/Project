# 프론트 MVP 페이지별 작업 명세

작성: 2026-10-25 · 기준: `api/openapi.yaml`의 "단계: MVP" API 37개 · 앱 코드(`FE/lib`) 현황 점검 결과

## 0. 먼저 읽을 것

### MVP 완료 기준
아래 한 바퀴가 앱에서 끝까지 돌면 프론트 MVP 완료입니다.

가입 → 신체정보 → 사진 올리고 분석 결과 보기 → 목표 체형 등록 → 오늘의 루틴 확인 → 운동하며 세트 기록·종료 → 기록 보기

### 서버 상태
- MVP 37개 API는 서버에 모두 구현되어 있습니다. 앱에서 호출만 하면 됩니다.
- **AI는 아직 가짜 응답(스텁)입니다.** 사진 분석·목표 체형은 사진 내용과 무관한 값을 줍니다. 응답의 `measurement_version`이 `stub-v0`이면 스텁입니다. 화면은 실제 응답과 같은 모양이므로 그대로 만들면 됩니다.
- 테스트용 서버가 필요하면 담당자(이지한)에게 요청합니다. Swagger 화면에서 모든 API를 직접 눌러 볼 수 있습니다.

### 공통 규칙
| 항목 | 규칙 |
|---|---|
| 주소 | 모든 경로는 `/api`로 시작. 앱은 `API_BASE_URL`(dart-define)로 서버를 지정 |
| 인증 | 로그인 응답의 `access_token`을 `Authorization: Bearer <토큰>`으로 보냄. 가입·로그인·인증메일 API만 토큰 없이 호출 |
| 토큰 만료 | 7일, 재발급 API 없음. **토큰을 보낸 요청**이 `401 UNAUTHORIZED`를 받으면 토큰을 지우고 로그인 화면으로 이동. 로그인 요청의 401(`INVALID_CREDENTIALS`)은 입력 오류이며 로그아웃 처리하지 않음 |
| 필드 이름 | JSON은 전부 `snake_case` |
| 시각 | `2026-10-25T09:00:00+09:00` 형식(KST). 날짜는 `2026-10-25` |
| 오류 응답 | `{code, message, status, fields[]}`. 화면 분기는 `code`로 하고, `message`는 그대로 보여 줘도 되는 한글 문구. 입력 검증 오류(`VALIDATION_FAILED`)는 `fields[]`에 `{field, reason}` |
| 목록 | `page`(1부터), `page_size`(기본 20, 최대 50). 응답은 `{items, page, page_size, total}` |
| 첫 화면 결정 | 앱 실행·로그인 직후 `GET /users/me`로 결정: `consent_completed=false` → 동의, `onboarding_completed=false` → 신체정보 입력, 그 외 홈 |
| 비동기 | 체형 분석·목표 체형은 즉시 `pending`을 주고 앱이 **2초마다** 조회. 앱은 최대 **60초**까지만 기다리고, 그래도 `pending`이면 "잠시 후 다시 확인해 주세요" 표시 |

### 현황 표기
- **연결됨**: 서버 API를 실제로 호출하는 코드가 있음
- **화면만**: 화면 UI는 있으나 서버 호출 없음(예시 데이터 또는 로컬 저장)
- **빈 화면**: 파일은 있으나 "준비 중" 문구뿐
- **없음**: 화면 파일 자체가 없음

---

## 1. 화면 지도

| # | 페이지 | 앱 파일 | 현황 | 주 API |
|---|---|---|---|---|
| P1 | 로그인 | `auth/.../login_page.dart` | 연결됨 | `POST /auth/login` |
| P2 | 회원가입 + 이메일 인증 | `auth/.../signup_page.dart` | 연결됨 | `POST /auth/email-verifications`, `/confirm`, `POST /users` |
| P3 | 동의 | `auth/.../consent_page.dart` | 화면만(확인 필요) | `GET/PATCH /users/me` |
| P4 | 신체정보 입력·수정 | `profile/.../profile_form_page.dart` | 연결됨 | `POST/PATCH/GET /users/me/profile` |
| P5 | 체형 분석 (사진 → 진행 → 결과) | `body_analysis/.../onboarding_analysis_page.dart` | 화면만 | `POST /photos`, `POST /body-analyses/photo`, `GET /body-analyses/{id}` |
| P6 | 목표 체형 | `goal_body/` | 없음 | `POST/GET/PATCH/DELETE /goal-bodies`, `POST /photos` |
| P7 | 홈 | `home/.../home_page.dart` | 화면만(예시 데이터) | `GET /routines/today`, `GET /workout-logs` |
| P8 | 주간 루틴 · 루틴 상세 | `routines/` | 없음 | `GET /routines/weekly`, `/routines/{id}`, `POST /routines` |
| P9 | 운동 종목 (목록·상세) | `exercises/` | 없음 | `GET /exercises`, `/exercises/{id}` |
| P10 | 운동 진행 | `workout/` | 없음 | `POST /workout-logs`, `.../sets` |
| P11 | 운동 종료 요약 | `workout/` | 없음 | `PATCH /workout-logs/{id}/complete` |
| P12 | 운동 기록 (달력·목록·상세) | `home/.../workout_calendar_page.dart`, `workout/.../workout_history_page.dart` | 달력은 화면만, 기록은 빈 화면 | `GET /workout-logs`, `/workout-logs/{id}` |
| P13 | 설정 · 내 정보 | `settings/` | 없음 | `GET/PATCH/DELETE /users/me`, `POST /auth/logout`, `/photos` |

MVP 밖(그대로 "준비 중"으로 두면 되는 것): AI 코치 탭, 커뮤니티 탭. 비밀번호 찾기(`password_reset_page`)는 명세상 2차지만 이미 서버·앱 모두 연결되어 있습니다.

### 권장 작업 순서
1. P5 → 2. P6 → 3. P8·P9 (루틴·종목 읽기 전용) → 4. P7 홈을 실제 데이터로 → 5. P10·P11 (운동 진행·종료) → 6. P12 → 7. P13 → 8. P3 점검

앞 단계가 뒤 단계의 입력이 됩니다. 분석이 있어야 루틴이 만들어지고, 루틴이 있어야 홈과 운동 진행이 의미가 있습니다.

---

## P1. 로그인

**현황:** 연결됨. 아래 항목만 점검합니다.

| 항목 | 내용 |
|---|---|
| 진입 | 앱 첫 실행(토큰 없음), 토큰 만료(401) |
| API | `POST /auth/login` → `{access_token, token_type, expires_in, onboarding_completed}` |
| 요청 | `{email(≤255), password(1~64)}` |
| 성공 후 | 토큰 저장 → `GET /users/me`로 첫 화면 결정 |
| 오류 | `INVALID_CREDENTIALS`(401): 이메일이 없는 경우와 비밀번호가 틀린 경우를 구분하지 않으니 "이메일 또는 비밀번호가 올바르지 않아요" 하나만 표시 |
| 링크 | 회원가입(P2), 비밀번호 찾기 |

점검 목록
- [ ] 토큰을 안전한 저장소에 보관하고, 앱 재실행 시 `GET /users/me`로 유효성 확인
- [ ] 401 수신 시 어느 화면에서든 토큰 삭제 후 로그인으로 이동(전역 처리)
- [ ] 구글·카카오 버튼은 "준비 중" 유지(서버 미구현, 2차)

---

## P2. 회원가입 + 이메일 인증

**현황:** 연결됨(인증번호 요청·확인·가입 코드 있음).

가입은 3단계입니다.

| 단계 | API | 요청 | 응답 |
|---|---|---|---|
| 1. 번호 받기 | `POST /auth/email-verifications` | `{email}` | `204` |
| 2. 번호 확인 | `POST /auth/email-verifications/confirm` | `{email, code(6자리)}` | `{verification_token, expires_in}` |
| 3. 가입 | `POST /users` | 아래 | `201 {user_id, email, nickname, created_at}` |

가입 요청: `{email, password(8~64), nickname(2~20), terms_agreed, privacy_agreed, body_photo_agreed, ai_processing_agreed, policy_version?, email_verification_token}`
- 동의 4개가 모두 `true`가 아니면 `TERMS_REQUIRED`. 사진·AI 동의를 체크박스 하나로 묶어 두 값을 같이 보내도 됩니다.
- 가입은 토큰을 주지 않습니다. 성공하면 앱이 이어서 `POST /auth/login`을 호출합니다.

화면 상태
- 인증번호 입력 칸: 5분 카운트다운. 만료되면 "다시 받기"
- "다시 받기" 버튼: 60초 쿨다운 표시
- 안내 문구: "메일이 안 보이면 스팸함도 확인해 주세요" (이미 있음)
- 이메일을 바꾸면 이전 인증은 무효이므로 인증 상태를 초기화

오류 코드
| 코드 | 상황 | 표시 |
|---|---|---|
| `EMAIL_DUPLICATED` (409) | 번호 요청·가입 시 이미 가입된 이메일 | 이메일 칸 아래에 표시 |
| `EMAIL_CODE_TOO_FREQUENT` (429) | 60초 안에 재요청, 1시간 5회 초과 | "잠시 후 다시 요청해 주세요" |
| `EMAIL_SEND_FAILED` (503) | 메일 발송 실패 | "메일을 보내지 못했어요" + 재시도 |
| `EMAIL_CODE_INVALID` (400) | 번호 불일치 | 번호 칸 오류 |
| `EMAIL_CODE_EXPIRED` (400) | 5분 경과 | "다시 받기" 유도 |
| `EMAIL_CODE_LOCKED` (429) | 5회 틀림 | 번호를 다시 받아야 함 |
| `EMAIL_NOT_VERIFIED` (400) | 인증 토큰 없음·만료(30분)·다른 이메일 | 인증 단계로 복귀 |
| `NICKNAME_DUPLICATED` (409) | 닉네임 중복 | 닉네임 칸 오류 |
| `TERMS_REQUIRED` (400) | 필수 동의 누락 | 체크박스 안내 |

점검 목록
- [ ] 개발 서버에서는 메일이 아니라 서버 로그에 인증번호가 찍힘(담당자에게 확인)
- [ ] `verification_token` 만료(30분) 후 가입 시 `EMAIL_NOT_VERIFIED` 처리

---

## P3. 동의

**현황:** 화면은 있으나 서버 연결을 확인해야 합니다. 가입 때 동의 4개를 이미 보내므로, 이 화면은 "동의가 비어 있는 계정"(`consent_completed=false`)에만 나옵니다.

| 항목 | 내용 |
|---|---|
| 진입 | `GET /users/me`의 `consent_completed=false` |
| API | `PATCH /users/me` `{terms_agreed, privacy_agreed, body_photo_agreed, ai_processing_agreed}` |
| 규칙 | `terms`·`privacy`는 `true`로만 바꿀 수 있음(철회는 회원 탈퇴). 4개가 모두 `true`가 되면 `consent_completed=true` |
| 성공 후 | `GET /users/me` 재조회 → 다음 화면 |

- [ ] 현재 `acceptRequiredConsents`가 서버를 호출하는지 확인하고, 아니면 `PATCH /users/me`로 연결

---

## P4. 신체정보 입력·수정

**현황:** 연결됨. 입력 범위와 오류 처리만 점검합니다.

| 항목 | 내용 |
|---|---|
| 진입 | 가입 직후(`onboarding_completed=false`), 설정에서 수정 |
| 최초 등록 | `POST /users/me/profile` → `201` (성공하면 `onboarding_completed=true`) |
| 수정 | `PATCH /users/me/profile` → 보낸 필드만 변경, 새 이력으로 저장 |
| 조회 | `GET /users/me/profile` (`404 PROFILE_NOT_FOUND`면 아직 미등록) |

필드와 범위
| 필드 | 범위·값 |
|---|---|
| `height_cm` | 100~250 |
| `weight_kg` | 30~250 |
| `age` | 10~100 |
| `gender` | `male` / `female` / `none` (생략 가능) |
| `goal_type` | `muscle`(근육 증가) / `diet`(감량) / `posture`(자세) |
| `weekly_frequency` | 1~7 |
| `experience_level` | `under3m`(3개월 미만) / `under1y`(1년 미만) / `over1y`(1년 이상) |

- `PATCH` 응답의 `routine_refresh_recommended=true`는 목표·빈도·경력이 바뀌었다는 뜻입니다. "맞춤 루틴을 새로 만들까요?" 안내를 띄우고, 동의하면 `POST /routines`(P8)를 호출합니다.
- `PROFILE_ALREADY_EXISTS`(409): 이미 등록된 상태에서 `POST`를 보낸 경우. `PATCH`로 전환합니다.

- [ ] 입력 범위를 앱에서도 검증(서버는 `VALIDATION_FAILED` + `fields[]`로 돌려줌)
- [ ] 수정 후 `routine_refresh_recommended` 안내 연결

---

## P5. 체형 분석 (사진 → 진행 → 결과)

**현황:** 화면은 있으나(`onboarding_analysis_page`, 435줄) 서버를 호출하지 않고 로컬에만 저장합니다. 이 페이지가 MVP에서 가장 큰 작업입니다. 화면 3개로 나눕니다.

### P5-1. 사진 촬영·선택 및 업로드

| 항목 | 내용 |
|---|---|
| API | `POST /photos` (multipart: `image`, `type=current`, `side=front\|side`) |
| 응답 | `201 {photo_id, type, side, url, url_expires_at, created_at}` |
| 필요 사진 | 정면(`front`) 필수, 측면(`side`) 선택(없으면 목 각도를 측정하지 못함) |

앱이 업로드 전에 반드시 할 일
- 긴 변을 **1024px 이하**로 줄임
- **촬영 방향(EXIF 회전)을 픽셀에 반영**한 JPG로 변환. 안 하면 사진이 눕혀진 채 분석되어 `NO_PERSON`·`NOT_FULL_BODY` 실패가 납니다.
- 10MB 이하 확인(서버도 거부)

오류 코드
| 코드 | 상황 |
|---|---|
| `PHOTO_LIMIT_EXCEEDED` (409) | 사진 20장 초과 → 목록에서 삭제하도록 안내(P13) |
| `IMAGE_TOO_LARGE` (413) | 10MB 초과 |
| `IMAGE_INVALID_TYPE` (415) | JPG·PNG가 아님 |
| `CONSENT_REQUIRED` (403) | 사진 동의 철회 → 설정의 동의 화면으로 안내 |
| `ONBOARDING_REQUIRED` (403) | 신체정보 미입력 → P4로 이동 |

- 사진 `url`은 1시간짜리 서명 주소입니다. 만료되면 `GET /photos`로 새로 받습니다.

### P5-2. 분석 진행 (폴링)

| 항목 | 내용 |
|---|---|
| 요청 | `POST /body-analyses/photo` `{photo_id, side_photo_id?, goal_body_id?}` → `202 {analysis_id, status: pending, poll_after_ms, created_at}` |
| 폴링 | `GET /body-analyses/{analysis_id}`를 2초마다, 최대 60초 |
| 종료 조건 | `status`가 `done` 또는 `failed` |

- `goal_body_id`를 보내면 목표와의 비교(`goal_comparison`)까지 받습니다. 목표가 `done` 상태여야 합니다(`GOAL_NOT_READY`).
- 진행 중 화면: 진행 안내 + 취소 대신 "잠시 후 다시 확인" 처리.

오류 코드
| 코드 | 상황 | 표시 |
|---|---|---|
| `ANALYSIS_IN_PROGRESS` (409) | 이미 분석 중인 요청이 있음 | 진행 중인 분석 화면으로 이동 |
| `ANALYSIS_QUOTA_EXCEEDED` (429) | 하루 3회 한도 | 남은 횟수는 `GET /body-analyses/usage`의 `reset_at`(KST 자정)까지 |
| `PHOTO_TYPE_MISMATCH` (400) | 정면/측면 사진 종류가 다름 | 사진을 다시 선택 |
| `GOAL_NOT_READY` (409) | 목표 체형이 아직 처리 중 | 잠시 후 다시 |
| `CONSENT_REQUIRED` (403) | 사진·AI 동의 철회 | 동의 화면 |

### P5-3. 분석 결과

`GET /body-analyses/{analysis_id}` 응답으로 화면을 그립니다.

**`status=failed`는 HTTP 오류가 아니라 `200`입니다.** `error_code`로 안내를 바꿉니다.
| `error_code` | 안내 |
|---|---|
| `IMAGE_BLURRY` | 사진이 흐려요. 다시 촬영해 주세요 |
| `NO_PERSON`, `NOT_FULL_BODY` | 전신이 나오게 촬영해 주세요 |
| `MULTIPLE_PEOPLE` | 한 명만 나오게 촬영해 주세요 |
| `NOT_FRONTAL` | 정면으로 서서 촬영해 주세요 |
| `AI_FAILED`, `AI_TIMEOUT` | 잠시 후 다시 시도해 주세요 |

`status=done`일 때 표시할 값
| 필드 | 설명 |
|---|---|
| `measures` | `shoulder_tilt_deg`, `pelvis_tilt_deg`, `neck_forward_deg`, `shoulder_hip_ratio`, `torso_leg_ratio`. **측정하지 못한 값은 `null`**이고 `measures.unavailable[]`에 사유가 있음. null을 0으로 그리지 말 것 |
| `judgements[]` | 항목별 `{item, label, value, unit, level, reason}`. `level`: `good`(양호) / `caution`(주의) / `unavailable`(평가 불가) |
| `balance_score` | 0~100. **null일 수 있음**(판정 기준 검증 전) |
| `body_type` | 역삼각형 / 직사각형 / 사다리꼴, null 가능 |
| `goal_comparison` | 목표를 함께 보냈을 때만. `{priority_parts[], summary, detail}` |

- 분석이 `done`이 되어도 **루틴은 자동으로 만들어지지 않습니다.** 결과 화면의 "맞춤 루틴 만들기" 버튼이 `POST /routines`(P8)를 호출합니다.
- 분석 기록 목록: `GET /body-analyses` (`{analysis_id, status, source, balance_score, body_type, goal_body_id, created_at}`)
- 남은 횟수: `GET /body-analyses/usage` → `{used, limit, remaining, reset_at}`

점검 목록
- [ ] 이미지 전처리(리사이즈·EXIF 회전 반영)는 `core/media/image_preprocessor.dart`에 있음 → 업로드에 연결
- [ ] 폴링은 화면을 벗어나면 중단하고, 돌아오면 `analysis_id`로 재개
- [ ] `null` 값은 "측정하지 못했어요"로 표시

---

## P6. 목표 체형

**현황:** 폴더만 있고 화면이 없습니다.

| 항목 | 내용 |
|---|---|
| 등록 | `POST /goal-bodies` `{photo_id?, description?(1~200자)}` → `201` |
| 조회 | `GET /goal-bodies` (없으면 `404 GOAL_NOT_FOUND`) |
| 수정 | `PATCH /goal-bodies/{id}` 같은 필드 |
| 삭제 | `DELETE /goal-bodies/{id}` → `204` |

응답: `{goal_body_id, status(pending/done/failed), summary, error_message, poll_after_ms, description, created_at}`

동작 규칙
- 목표 사진은 `POST /photos`에서 **`type=goal`** 로 올립니다.
- **설명만 보내면** AI 호출 없이 바로 `done`. **사진을 보내면** `pending` → 앱이 `GET /goal-bodies`를 2초마다 조회 → `done`(또는 `failed`).
- 목표 사진은 **임시 파일**입니다. 올린 뒤 1시간 안에 등록하지 않으면 서버가 지우고, 등록하면 특징 추출 직후 서버가 지웁니다. 그래서 등록 후 목표 사진 미리보기는 보여 줄 수 없습니다. `summary`(특징 요약)와 `description`을 보여 줍니다.
- 사용자당 목표는 1개입니다(`GOAL_ALREADY_EXISTS` 409 → 수정으로 전환).
- 이미 끝난 분석 결과는 목표를 바꿔도 변하지 않습니다. 새 목표로 비교하려면 분석을 다시 요청합니다.
- 사진 등록은 사진·AI 동의가 모두 필요합니다(`CONSENT_REQUIRED`).

화면 구성: 설명 입력 + 사진 선택(선택) + 저장. 저장 후 상태(`pending`/`done`/`failed`)에 따라 안내.

- [ ] 사진 없이 설명만으로 등록하는 경로 지원
- [ ] `failed`일 때 `error_message` 표시 + 다시 시도

---

## P7. 홈

**현황:** 화면(949줄)에 수동 일정(요일별 운동·휴식, 매주 반복)·로컬 운동 기록·달력이 이미 동작합니다. 서버 연결만 없습니다. **기존 기능과 디자인은 보존하고 서버 데이터를 덧붙입니다**(결정 D1: 수동 일정은 로컬 유지, 서버 루틴은 선택, 휴식일은 `PATCH /routines/{id}` `skipped`로 동기화).

| 영역 | API | 비고 |
|---|---|---|
| 오늘의 루틴 카드 | `GET /routines/today` | 루틴이 없으면 `is_rest_day=true`, `routine=null` (오류가 아님) → "오늘은 쉬는 날" |
| 루틴 진행률 | `routine.items[].done` | 완료한 종목 수 / 전체 |
| 캘린더 점 | `GET /workout-logs?start_date&end_date` → `summary.workout_dates` | 운동한 날 표시 |
| 오늘 총 볼륨 | 오늘 하루로 같은 API 조회 → `summary.total_volume_kg` | 진행 중인 종목의 세트는 앱이 더해서 보정 |
| 이어하기 | `GET /workout-logs?status=in_progress` | 진행 중인 기록이 있으면 "이어서 운동하기" |
| 분석이 없을 때 | `GET /body-analyses` | 분석 기록이 없으면 "체형 분석하고 루틴 받기"로 P5 유도 |

- [ ] 분석·루틴이 없는 신규 사용자 상태(빈 상태 화면)를 별도로 처리
- [ ] 서버 모드에서 예시 데이터를 쓰지 않음(로컬 미리보기 모드는 기존대로 유지)
- [ ] `ONBOARDING_REQUIRED`(403)를 받으면 P4로 이동

---

## P8. 주간 루틴 · 루틴 상세

**현황:** 없음.

### 루틴 만들기
- `POST /routines` `{analysis_id}` → `201 {analysis_id, routines[]}`
- 오늘부터 **7일** 중 `weekly_frequency`일에 하루 1개씩 만들고 나머지는 휴식일입니다.
- 오늘 이후의 `planned` 루틴은 **새로 만든 것으로 교체**되고, `done`·`skipped`는 유지됩니다. 같은 분석으로 다시 호출해도 오류가 아닙니다.
- `ANALYSIS_NOT_READY`(409): 분석이 `done`이 아님. `NOT_FOUND`(404): 분석 ID 오류.

### 주간 루틴 (월~일 7칸)
- `GET /routines/weekly?week_start=YYYY-MM-DD` (월요일만 허용, 생략하면 이번 주. 월요일이 아니면 `VALIDATION_FAILED`)
- 응답: `{week_start, days[{date, is_rest_day, routine{routine_id, title, target_part, estimated_minutes, status, item_count, done_count}}]}`
- 루틴이 없는 날은 `is_rest_day=true`, `routine=null`.

### 루틴 상세
- `GET /routines/{routine_id}` → `{routine_id, scheduled_date, title, target_part, estimated_minutes, status(planned/done/skipped), items[]}`
- `items[]`: `{item_id, order_no, exercise{...}, target_sets, target_reps, target_weight_kg(null 가능), rest_sec, reason, done}`
- `reason`은 그 운동이 뽑힌 이유(예: "분석 결과 집중 부위(어깨)를 위한 운동입니다"). 카드에 한 줄로 보여 주면 좋습니다.
- 각 종목의 "시작" 버튼 → P10(`routine_id`와 함께 운동 시작).

### 루틴 건너뛰기·되돌리기
- `PATCH /routines/{routine_id}` `{"status": "skipped"}` 건너뛰기 / `{"status": "planned"}` 되돌리기 → 루틴 상세 응답.
- 되돌리기는 **오늘 이후 날짜만** 가능합니다. 지난 날짜는 `VALIDATION_FAILED`. 이미 `done`이면 둘 다 `VALIDATION_FAILED`. 같은 상태를 다시 보내도 오류가 아닙니다.
- 앱의 수동 일정에서 휴식일로 바꾸거나 해제할 때 서버 루틴과 맞추는 용도입니다(정책은 팀원용 문서의 D1-a, D1-b).

- [ ] 루틴 생성 버튼(분석 결과 화면, 신체정보 수정 후 안내)
- [ ] `target_weight_kg`가 null이면 "직접 입력" 표시

---

## P9. 운동 종목 (목록·상세)

**현황:** 없음. 자유 운동 추가 화면에서 씁니다.

| 항목 | 내용 |
|---|---|
| 목록 | `GET /exercises` 필터: `target_part`(chest/back/leg/shoulder/arm/core), `difficulty`(이 값 이하), `equipment`(barbell/dumbbell/machine/bodyweight), `q`(이름 검색, 공백 무시), `page`, `page_size` |
| 상세 | `GET /exercises/{exercise_id}` → 목록 필드 + `description` |

- 응답의 `min_sets`·`max_sets`는 **사용자의 경력 기준**으로 서버가 채웁니다(같은 종목도 사람마다 다름).
- `media_url`은 null일 수 있습니다(시범 영상이 없는 종목).
- 화면: 부위 칩 + 기구 필터 + 검색창 + 목록. 종목을 고르면 `POST /workout-logs`를 `routine_id` 없이 호출해 자유 운동으로 시작합니다.

---

## P10. 운동 진행

**현황:** 없음. 앱에서 가장 복잡한 화면입니다.

종목 하나를 실행할 때마다 **운동 기록(log) 1개**를 만듭니다. 4종목 루틴이면 4번 시작합니다.

| 동작 | API |
|---|---|
| 시작 | `POST /workout-logs` `{exercise_id, routine_id?}` → 새로 만들면 `201`, 같은 종목의 진행 중 기록이 있으면 새로 만들지 않고 **`200 + resumed=true`** |
| 세트 완료 | `POST /workout-logs/{log_id}/sets` `{client_set_id, set_no, weight_kg, reps, rest_sec?, is_done?}` |
| 세트 수정 | `PATCH /workout-logs/{log_id}/sets/{set_id}` `{version, weight_kg?, reps?, is_done?, rest_sec?}` |
| 세트 삭제 | `DELETE /workout-logs/{log_id}/sets/{set_id}` → `204` |
| 취소 | `DELETE /workout-logs/{log_id}` → `204` (세트도 함께 삭제) |

핵심 규칙 (모르면 버그가 나는 부분)
- **`client_set_id`는 세트마다 앱이 만드는 UUID(36자)입니다.** 응답을 못 받았거나 앱이 꺼졌다 켜지면 **같은 값으로 다시 보내세요.** 서버는 새로 만들지 않고 저장된 세트를 `200`으로 돌려줍니다(중복 방지).
- 세트 추가 요청에 `exercise_id`는 보내지 않습니다(기록에 이미 정해짐).
- `set_no`는 1~20, `weight_kg` 0~500, `reps` 1~100, `rest_sec` 0~3600.
- 세트 수정 시 `version`을 함께 보냅니다. 서버 값과 다르면 `VERSION_CONFLICT`(409) → 기록을 다시 조회하고 사용자가 확인한 뒤 다시 수정합니다. 성공하면 `version`이 1 올라갑니다.
- 세트를 지워도 다른 세트의 `set_no`는 다시 매기지 않습니다.
- 경과 시간은 앱이 직접 세지 말고 **`지금 − started_at`** 으로 계산하세요. 앱을 나갔다 와도 복구됩니다.
- **휴식 타이머는 앱에서만 셉니다.** 기본값은 루틴의 `items[].rest_sec`. 세트에 보내는 `rest_sec`는 실제로 쉰 시간입니다.
- 진행 중 기록이 **6시간을 넘으면 서버가 자동으로 중단(`aborted`)** 합니다. 중단된 기록은 이어하기·통계에서 제외됩니다.
- 앱 시작 시 `GET /workout-logs?status=in_progress`로 진행 중 기록이 있는지 확인해 "이어하기"를 띄웁니다.

오류 코드
| 코드 | 상황 |
|---|---|
| `WORKOUT_ALREADY_COMPLETED` (409) | 이미 끝난 기록에 세트 추가 |
| `SET_DUPLICATED` (409) | 같은 `set_no`가 이미 있음 |
| `VALIDATION_FAILED` (400) | `routine_id`를 보냈는데 그 루틴의 종목이 아님, 또는 범위 오류 |
| `NOT_FOUND` (404) | 없는 종목·루틴·기록 |

화면 구성: 종목명, 목표(세트×횟수), 세트 입력 목록(무게·횟수·완료 체크), 휴식 타이머, 경과 시간, 종목 종료 버튼.

---

## P11. 운동 종료 요약

**현황:** 없음.

| 항목 | 내용 |
|---|---|
| API | `PATCH /workout-logs/{log_id}/complete` `{duration_sec?, memo?}` |
| 응답 | `{log_id, completed_at, duration_sec, total_volume_kg, set_count, routine_progress{done,total}\|null, routine_status\|null}` |

- `duration_sec`을 보내지 않으면 서버가 `completed_at − started_at`으로 정합니다. 보낸 값이 경과 시간보다 크면 경과 시간으로 보정됩니다(최대 21600).
- **완료 세트가 0개면 `WORKOUT_EMPTY`(400).** 이때 앱은 `DELETE /workout-logs/{log_id}`로 기록을 지웁니다.
- `total_volume_kg`는 완료 세트의 `weight_kg × reps` 합입니다.
- 루틴에서 시작한 기록이면 `routine_progress`로 "3/4 종목 완료"를 표시합니다. 모든 종목이 끝나면 `routine_status=done`이고, 이때 "오늘 루틴 완료" 화면을 보여 줍니다.
- `WORKOUT_ALREADY_COMPLETED`(409): 이미 종료된 기록.

화면 구성: 운동 시간, 총 볼륨, 세트 수, 루틴 진행률, 메모 입력, "다음 종목" / "홈으로".

---

## P12. 운동 기록 (달력·목록·상세)

**현황:** 달력은 화면만, 기록 목록은 빈 화면입니다.

| 항목 | 내용 |
|---|---|
| 목록 | `GET /workout-logs?start_date=&end_date=&status=&page=&page_size=` (두 날짜 필수, 범위는 **최대 92일**) |
| 상세 | `GET /workout-logs/{log_id}` |
| 삭제 | `DELETE /workout-logs/{log_id}` |

목록 응답
- `summary`: `{log_count, workout_days, total_sets, total_volume_kg, total_duration_sec, workout_dates[]}` — **페이지와 무관하게 조회 기간 전체의 "종료된 기록" 합계**입니다. 달력의 운동한 날 표시는 `workout_dates`를 씁니다.
- `items[]`: `{log_id, exercise{exercise_id,name,target_part}, routine_id, workout_date, started_at, completed_at, duration_sec, status, set_count, total_volume_kg}`
- `status`: `in_progress` / `completed` / `aborted`. 중단(`aborted`) 기록은 목록에는 나오지만 통계에는 들어가지 않습니다.

상세 응답: 위 필드 + `memo`, `sets[]{set_id, client_set_id, set_no, version, weight_kg, reps, rest_sec, is_done}`

- 종료된 기록의 세트도 수정할 수 있습니다(`PATCH .../sets/{set_id}`, `version` 필요).
- 기록을 삭제하면 루틴의 종목 완료 상태와 진행률이 서버에서 다시 계산됩니다.

- [ ] 달력(월 단위)이 `start_date`~`end_date` 92일 제한을 넘지 않게 호출
- [ ] `aborted` 기록 표시 방식 정하기(회색 처리 등)

---

## P13. 설정 · 내 정보

**현황:** 없음(`features/settings` 폴더만 있음).

| 기능 | API | 비고 |
|---|---|---|
| 내 정보 | `GET /users/me` | 이메일, 닉네임, 동의 상태 |
| 닉네임 변경 | `PATCH /users/me` `{nickname}` | 2~20자. `NICKNAME_DUPLICATED`(409). 현재 닉네임 그대로 보내면 성공 |
| 사진·AI 동의 철회 | `PATCH /users/me` `{body_photo_agreed, ai_processing_agreed}` | 아래 참고 |
| 신체정보 수정 | P4 | |
| 내 사진 목록 | `GET /photos?type=` | 서명 URL은 조회할 때마다 새로 발급 |
| 사진 삭제 | `DELETE /photos/{photo_id}` | 분석 결과는 남고 사진만 지워짐. 목표 체형 처리 중인 사진은 `PHOTO_IN_USE`(409) |
| 사진 전체 삭제 | `DELETE /photos?type=current\|goal` | `{deleted_count, skipped_count}` |
| 로그아웃 | `POST /auth/logout` → `204` | 서버는 아무 처리도 하지 않음. **앱이 저장된 토큰을 지우면 끝** |
| 회원 탈퇴 | `DELETE /users/me` → `204` | 즉시 로그인 불가, 개인정보·사진·분석·운동 기록 삭제. 같은 이메일로 재가입 가능 |

동의 철회 시 안내 문구가 필요합니다
- **`body_photo_agreed=false`**: 새 사진 업로드가 막힙니다. 이미 올린 사진은 앱이 `DELETE /photos`로 지우도록 안내합니다.
- **`ai_processing_agreed=false`**: 진행 중인 AI 요청이 중단되고 새 분석은 `CONSENT_REQUIRED`가 됩니다. 만들어진 결과는 계속 볼 수 있습니다. 끄기 전에 "진행 중인 분석이 취소돼요" 확인 창을 띄우세요.

회원 탈퇴
- 되돌릴 수 없으므로 확인 창을 한 번 더 띄웁니다.
- 성공(`204`)하면 토큰과 로컬 데이터를 지우고 로그인 화면으로 이동합니다.

---

## 2. 공통 오류 처리 요약

| HTTP | 코드 | 앱 동작 |
|---|---|---|
| 401 | `UNAUTHORIZED` | 토큰 삭제 → 로그인 화면(전역) |
| 403 | `ONBOARDING_REQUIRED` | 신체정보 입력(P4)으로 이동 |
| 403 | `CONSENT_REQUIRED` | 설정의 동의 화면으로 안내 |
| 400 | `VALIDATION_FAILED` | `fields[]`의 `field`에 맞는 입력 칸에 `reason` 표시 |
| 404 | `NOT_FOUND` | "찾을 수 없어요" + 이전 화면 |
| 5xx | `INTERNAL_ERROR` 등 | "잠시 후 다시 시도해 주세요" + 재시도 |

## 3. 자주 하는 실수

1. 분석 `failed`를 HTTP 오류로 처리 → `200`으로 오므로 `status`를 봐야 합니다.
2. 분석 결과의 `null`을 0으로 표시 → "측정하지 못했어요"로 보여 주세요.
3. 업로드 전에 EXIF 회전을 반영하지 않음 → 분석이 계속 실패합니다.
4. 세트 재전송 때 새 UUID 생성 → 같은 세트가 두 번 쌓입니다. 한 번 만든 `client_set_id`를 유지하세요.
5. 운동 경과 시간을 앱 타이머로만 계산 → 앱을 나가면 어긋납니다. `started_at` 기준으로 계산하세요.
6. 달력에서 92일을 넘는 기간으로 기록 조회 → `VALIDATION_FAILED`.
7. 분석 완료 후 루틴이 자동 생성될 거라 기대 → 앱이 `POST /routines`를 호출해야 합니다.

## 4. 참고

- API 전체 명세: `api/openapi.yaml` (Swagger 화면에서도 확인)
- 서버가 아직 안 만든 것(앱이 건드리지 않아도 됨): 구글·카카오 로그인, 푸시 발송
