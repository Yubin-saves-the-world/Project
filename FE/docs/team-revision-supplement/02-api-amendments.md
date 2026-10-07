> 현재 API 기준은 [팀장 API 명세](../api-baseline/README.md)입니다. 이 문서의 이전 제안과 충돌하면 최신 기준을 따릅니다.

# API 변경 계약과 교정 예시

팀장 API의 /api 접두사·JSON 응답 구조·페이지 규칙을 유지한다. 아래는 해당 엔드포인트에 병합할 변경 계약이다. 응답 예시는 문법뿐 아니라 상태·입력·시간 규칙도 지켜야 한다. 예시 수치는 실제 분석·운동 처방의 검증 결과가 아니다.

## 1. 변경표

| API | 입력·응답·예외 변경 |
| --- | --- |
| POST /api/users, POST /api/auth/oauth/google | terms_agreed·privacy_agreed 필수 true. body_photo_agreed·ai_processing_agreed 선택, 신규 가입 생략 시 false. 기존 Google 사용자 로그인에는 가입 동의 값을 다시 요구하지 않음 |
| GET/PATCH /api/users/me | consent_completed는 필수 약관 2종 완료. 기존 사진·AI 플래그 유지. 앱 진입에 사진·AI 동의를 요구하지 않음 |
| PATCH /api/auth/password/reset | 성공 시 token_version 증가. 기존 JWT는 다음 인증 요청부터 401 |
| POST /api/body-analyses/photo | 목표 지정 시 done 검증, pending이면 409 GOAL_NOT_READY. 목표·프로필 입력 스냅샷 저장 |
| GET /api/body-analyses/{analysis_id} | 기존 실패 코드에 CONSENT_WITHDRAWN·INPUT_PHOTO_DELETED 추가. HTTP 200/status=failed로 반환. 완료 결과와 오류 필드 동시 반환 금지 |
| 분석 결과 goal_comparison | done이고 요청 당시 목표 스냅샷이 있으면 반환. 현재 goal_body_id가 삭제로 null이어도 저장된 비교는 유지. FK 존재 여부만으로 비교를 지우지 않음 |
| POST/PATCH/GET /api/goal-bodies | revision 정수, error_code nullable 필드 추가. pending 시 poll_after_ms=2000, 그 외 null. 실패 코드 AI_FAILED·AI_TIMEOUT·CONSENT_WITHDRAWN·INPUT_PHOTO_DELETED. 사진 처리 요청은 pending에서 시작 |
| PATCH /api/goal-bodies/{goal_body_id} | pending이면 409 GOAL_PROCESSING. 입력 변경 성공 시 revision+1 |
| DELETE /api/goal-bodies/{goal_body_id} | 기존 204 유지. pending 작업 무효화와 임시 사진 정리 등록까지 완료 후 반환 |
| POST /api/routines | generated_from·generated_until(포함), warnings[] 추가. routines는 해당 범위의 최종 운동일 루틴 전체이며 기존 유지분도 포함. 잠긴 루틴 교체 금지. 409 ROUTINE_DATA_NOT_READY |
| 모든 루틴 객체 | revision, execution_locked, in_progress_count 추가. 상세에도 done_count·item_count 추가. 개인 중량 근거 없는 기구 운동의 target_weight_kg도 null 가능 |
| GET /api/routines/weekly | days[].schedule_state=ungenerated/rest/workout 추가. is_rest_day는 rest만 true. 7개 날짜를 항상 반환 |
| GET /api/routines/today | schedule_state 추가. 미생성·휴식일은 routine=null이지만 schedule_state로 구분 |
| POST /api/workout-logs | 동일 운동+루틴 맥락만 200 이어하기. 다른 진행 중 운동은 409 WORKOUT_IN_PROGRESS. 409 ROUTINE_NOT_STARTABLE·ROUTINE_ITEM_ALREADY_DONE 추가 |
| POST /api/workout-logs/{log_id}/sets | client_set_id 재전송 내용 일치 검증. 409 IDEMPOTENCY_CONFLICT·SET_NO_DUPLICATED 추가 |
| PATCH /api/workout-logs/{log_id}/sets/{set_id} | 성공 응답 version+1·수정 값 반환. 완료 세트 0개가 되는 변경은 409 COMPLETED_LOG_REQUIRES_DONE_SET |
| DELETE /api/workout-logs/{log_id}/sets/{set_id} | query version 필수(정수≥1). 409 VERSION_CONFLICT·COMPLETED_LOG_REQUIRES_DONE_SET 추가. 성공은 기존 204 |
| POST/PATCH 세트·GET 운동 상세 | weight_kg는 맨몸 운동에서 null 허용. 기구 운동은 0~500의 수치 입력. null은 미입력과 구분: PATCH 필드 생략은 유지, 명시 null은 맨몸만 허용 |
| PATCH /api/workout-logs/{log_id}/complete | completed 재요청은 기존 결과 200. aborted는 409 WORKOUT_NOT_EDITABLE. 완료 세트 0개면 409 NO_COMPLETED_SET |
| POST/PATCH/DELETE 세트 | aborted 로그에는 409 WORKOUT_NOT_EDITABLE. 세트 수정 및 완료 불변 조건은 서버 로그 잠금 안에서 확인 |
| PATCH /api/routines/{routine_id} | 시작 이력 있는 루틴 skip은 409 ROUTINE_ALREADY_STARTED. 같은 skipped 재요청은 동일 결과 200 |
| DELETE /api/users/me | 성공 202로 교체. 아래 접수 응답 반환. 영속 작업 등록 실패 503 ACCOUNT_DELETION_UNAVAILABLE |
| POST /api/diet-plans | 지원 범위 밖 산식은 409 DIET_FORMULA_NOT_APPLICABLE. 생성 중 알레르기 변경은 기존 생성 방식에 맞춰 failed/error_code=ALLERGY_CHANGED |
| GET /api/diet-plans, GET /api/diet-plans/{plan_id} | needs_regeneration, allergy_revision 추가. true이면 식사 항목 응답은 빈 배열, 경고 문구 반환. 최신 항목 구조의 나머지 필드는 원문 유지 |
| POST /api/ai/chat | client_request_id(UUID) 필수. pending 같은 요청은 409 AI_REQUEST_IN_PROGRESS, 내용 불일치 409 IDEMPOTENCY_CONFLICT. 같은 완료 요청은 기존 응답 200 |
| POST/GET /api/ai/chat | assistant 메시지에 suggestion nullable 포함. suggestion에 routine_id·base_revision·created_at 추가. 상태 expired 추가 |
| suggestion.changes[] | add/replace에 target_weight_kg(nullable) 추가. 맨몸·개인 처방 근거 없음은 null. remove면 처방값 모두 null. 휴식은 기존 90초 기본값 |
| POST /api/ai/routine-suggestions/{suggestion_id}/confirm | 409 SUGGESTION_EXPIRED·ROUTINE_VERSION_CONFLICT·ROUTINE_ALREADY_STARTED·SUGGESTION_ALREADY_DECIDED 추가. 동일 결정 재전송은 기존 결과 |
| GET/PATCH /api/admin/reports* | 기능 단계를 2차로 이동. 관리자 인증 필수 유지. 신고 판단·숨김 복구 기준은 요구사항 문서 적용 |
| GET /api/admin/users, GET /api/admin/users/{user_id} | deleted_at 존재 시 email·nickname null 가능. 삭제 개인정보를 재노출하지 않음 |
| 제휴 상품 조회 및 관리자 쓰기 | 기간·제휴사·상품 활성 여부 검사. is_advertisement=true만 허용 |
| GET /api/missions/current | 자동 참여 생성(사용자·미션당 1개), joined_at 추가. 미션이 없으면 원문의 빈 응답 유지 |
| GET /api/user-coupons/{user_coupon_id} | code·redemption_url·redemption_instructions·used_at(nullable) 추가. expires_at은 원문 필드 유지 |
| DELETE /api/users/me/device-token | 신규 확장 API. query platform=ios/android 필수. 본인 플랫폼 연결 해제, 성공 204. 이미 없으면 204 |

단순 404 소유권 은닉은 개인 데이터와 다른 사용자의 수정·삭제에 적용한다. 공개 콘텐츠 조회에는 공개·차단·숨김 정책을 적용한다. 정적 경로 /usage, /weekly, /today, /stats 등은 ID 경로와 충돌하지 않도록 등록한다.

오류 응답의 envelope는 원문 공통 규칙을 유지한다. 추가 오류 코드를 프론트가 enum으로 처리하는 경우 함께 갱신한다. WORKOUT_IN_PROGRESS는 기존 GET /api/workout-logs의 status 필터로 기록을 조회하도록 안내한다. 새로운 current API는 추가하지 않는다.

## 2. 수정된 핵심 응답 예시

### 2.1 사진 분석 완료: 측면 없음·판정 기준 미검증

GET /api/body-analyses/31 → 200

```json
{
  "analysis_id": 31,
  "status": "done",
  "source": "photo",
  "error_code": null,
  "error_message": null,
  "photo_id": 12,
  "side_photo_id": null,
  "goal_body_id": 4,
  "measures": {
    "shoulder_tilt_deg": 3.2,
    "pelvis_tilt_deg": 1.1,
    "neck_forward_deg": null,
    "shoulder_hip_ratio": 1.32,
    "torso_leg_ratio": 0.85,
    "unavailable": [{"key": "neck_forward", "reason": "SIDE_PHOTO_MISSING"}]
  },
  "balance_score": null,
  "measurement_version": "draft-v1",
  "body_type": null,
  "judgements": [
    {"item": "shoulder_tilt", "label": "어깨 좌우 높이차", "value": 3.2, "unit": "deg", "level": "unavailable", "reason": "PROFILE_NOT_VALIDATED"},
    {"item": "pelvis_tilt", "label": "골반 좌우 기울기", "value": 1.1, "unit": "deg", "level": "unavailable", "reason": "PROFILE_NOT_VALIDATED"},
    {"item": "neck_forward", "label": "목 전방 기울기", "value": null, "unit": "deg", "level": "unavailable", "reason": "SIDE_PHOTO_MISSING"}
  ],
  "goal_comparison": {
    "priority_parts": [{"part": "shoulder", "label": "어깨"}],
    "summary": "목표 설명을 반영해 어깨 운동을 우선 제안해요.",
    "detail": "분석 당시 저장된 목표 설명을 참고한 AI 제안입니다. 근육량이나 두께를 측정한 결과는 아닙니다."
  },
  "text_summary": null,
  "created_at": "2026-10-06T19:02:10+09:00",
  "completed_at": "2026-10-06T19:02:22+09:00"
}
```

### 2.2 사진 목표 등록 접수

POST /api/goal-bodies 요청 `{"photo_id":15,"description":"어깨를 강조한 체형"}` → 201

```json
{
  "goal_body_id": 4,
  "revision": 1,
  "status": "pending",
  "summary": null,
  "error_code": null,
  "error_message": null,
  "poll_after_ms": 2000,
  "description": "어깨를 강조한 체형",
  "created_at": "2026-10-06T19:02:10+09:00"
}
```

완료 시 status=done, summary는 추출한 설명, error_code/error_message/poll_after_ms는 null이다. 설명만 등록하면 즉시 done이며 summary=null이다. photo_id와 description을 모두 생략하거나 빈 문자열만 보내면 400 VALIDATION_FAILED다.

### 2.3 동의 철회 후 홈 접근

GET /api/users/me → 200

```json
{
  "user_id": 12,
  "email": "user@example.com",
  "nickname": "지한",
  "role": "user",
  "onboarding_completed": true,
  "consent_completed": true,
  "body_photo_agreed": false,
  "ai_processing_agreed": false,
  "created_at": "2026-09-28T19:02:10+09:00"
}
```

위 경우 홈으로 진입한다. 새 사진·AI 기능을 실행할 때 동의 화면을 안내한다.

### 2.4 7개 날짜: 휴식일과 미생성 날짜 구분

GET /api/routines/weekly?week_start=2026-10-05 → 200

```json
{
  "week_start": "2026-10-05",
  "days": [
    {"date": "2026-10-05", "schedule_state": "ungenerated", "is_rest_day": false, "routine": null},
    {"date": "2026-10-06", "schedule_state": "workout", "is_rest_day": false, "routine": {"routine_id": 44, "scheduled_date": "2026-10-06", "title": "기본 전신 운동", "target_part": "leg", "estimated_minutes": 30, "status": "planned", "revision": 1, "execution_locked": false, "item_count": 3, "done_count": 0, "in_progress_count": 0}},
    {"date": "2026-10-07", "schedule_state": "rest", "is_rest_day": true, "routine": null},
    {"date": "2026-10-08", "schedule_state": "workout", "is_rest_day": false, "routine": {"routine_id": 45, "scheduled_date": "2026-10-08", "title": "기본 전신 운동", "target_part": "back", "estimated_minutes": 30, "status": "planned", "revision": 1, "execution_locked": false, "item_count": 3, "done_count": 0, "in_progress_count": 0}},
    {"date": "2026-10-09", "schedule_state": "rest", "is_rest_day": true, "routine": null},
    {"date": "2026-10-10", "schedule_state": "workout", "is_rest_day": false, "routine": {"routine_id": 46, "scheduled_date": "2026-10-10", "title": "기본 전신 운동", "target_part": "core", "estimated_minutes": 30, "status": "planned", "revision": 1, "execution_locked": false, "item_count": 3, "done_count": 0, "in_progress_count": 0}},
    {"date": "2026-10-11", "schedule_state": "rest", "is_rest_day": true, "routine": null}
  ]
}
```

today의 미생성 응답은 `{"date":"2026-10-05","schedule_state":"ungenerated","is_rest_day":false,"routine":null}`이다. 앱은 is_rest_day만으로 화면을 분기하지 않는다.

### 2.5 세트 수정 성공

PATCH /api/workout-logs/87/sets/842

```json
{"version": 1, "weight_kg": 62.5, "reps": 10, "is_done": true, "rest_sec": 90}
```

응답 200:

```json
{
  "set_id": 842,
  "client_set_id": "3f2b8c1e-5a47-4d0e-9b6a-1c2d3e4f5a6b",
  "set_no": 1,
  "version": 2,
  "weight_kg": 62.5,
  "reps": 10,
  "rest_sec": 90,
  "is_done": true
}
```

세트 삭제는 DELETE /api/workout-logs/87/sets/842?version=2다. 마지막 완료 세트라면 삭제하지 않고 409 COMPLETED_LOG_REQUIRES_DONE_SET이다.

### 2.6 탈퇴 접수

DELETE /api/users/me → 202

```json
{
  "status": "accepted",
  "access_revoked": true,
  "cleanup_status": "pending",
  "accepted_at": "2026-10-06T19:02:10+09:00"
}
```

이 응답은 계정 접근 차단과 정리 작업의 영속 등록 완료를 뜻하며 외부 파일 물리 삭제 완료를 뜻하지 않는다. 정리 상태 외부 조회 API는 추가하지 않는다. 이후 토큰을 통한 개인 조회는 401이다.

### 2.7 AI 대화와 제안 복원

POST /api/ai/chat 요청:

```json
{"client_request_id":"52b81fc5-d885-4a06-a46a-dc08c655d96c","content":"오늘 루틴에 다른 맨몸 종목을 제안해줘"}
```

응답 200:

```json
{
  "user_message": {"message_id": 501, "role": "user", "content": "오늘 루틴에 다른 맨몸 종목을 제안해줘", "created_at": "2026-10-06T19:02:10+09:00"},
  "reply": {"message_id": 502, "role": "assistant", "content": "현재 루틴의 종목 하나를 다른 맨몸 종목으로 바꾸는 안을 제안했어요. 적용 전에 변경 내용을 확인해 주세요.", "created_at": "2026-10-06T19:02:15+09:00"},
  "suggestion": {
    "suggestion_id": 77,
    "routine_id": 44,
    "base_revision": 1,
    "summary": "맨몸 종목 1개 교체",
    "changes": [{
      "action": "replace",
      "routine_item_id": 201,
      "exercise": {"exercise_id": 18, "name": "힙 브릿지", "target_part": "leg", "equipment": "bodyweight", "difficulty": 1, "min_sets": 2, "max_sets": 3, "media_url": null},
      "target_sets": 2,
      "target_reps": 10,
      "target_weight_kg": null
    }],
    "status": "pending",
    "created_at": "2026-10-06T19:02:15+09:00",
    "expires_at": "2026-10-07T19:02:15+09:00"
  },
  "remaining_today": 29
}
```

GET 대화 기록의 assistant items[].suggestion은 위 suggestion과 같은 구조다. 사용자 메시지는 suggestion=null이다. 제안 상태는 조회 시 최신값이며 expires_at을 지나면 expired로 반환한다. 적용 후 동일 승인 재요청은 applied 결과를 반환한다.

## 3. 원문 예시 전체 교정 기준

아래 항목은 관련 예시를 직접 교체할 때 적용하는 규칙이다. 필드를 그대로 복사하는 대신 실제 요청·상태와 일치하는 값을 사용한다.

| 원문 예시의 불일치 | 교정 |
| --- | --- |
| done 분석의 실패 메시지 | error_code와 error_message 모두 null |
| 정면만 입력했는데 목 각도 18 | neck_forward_deg=null, 해당 unavailable 사유 SIDE_PHOTO_MISSING |
| 어깨 측정값이 있는데 어깨 측정 불가 | 측정 불가 목록에서 제거. 미검증 판정은 judgements에 기록 |
| draft-v1의 점수 72·good 판정·체형 확정 | 산식·분류 미검증 예시는 score/body_type=null, level=unavailable |
| 사진 분석의 text_summary | null |
| 사진 목표 접수 예시 done·실패 메시지 혼재 | pending·summary=null·오류 null·poll_after_ms=2000 |
| done 목표의 poll_after_ms=2000 | null |
| 사진 URL 만료 시각이 생성 시각과 동일 | 조회 시 URL 발급 시각+1시간. created_at과 별개 |
| 사진 목록 total=57, 보유 한도20 | 해당 사용자 미삭제 사진 total≤20. 예시 total을 실제 items/page와 맞춤 |
| usage reset_at이 저녁 시각 | 다음 KST 자정. 10/6 19시 조회면 10/7 00:00+09:00 |
| 주간 days 한 칸·routine=null인데 rest=false | 위 7칸 예시로 교체, 미생성 상태 구분 |
| 스쿼트 reason이 어깨·등 두께 차이 | 하체/전신 목적 등 실제 종목 선택 규칙과 일치하는 설명 |
| 근거 없는 개인 목표 중량60 | 개인 처방 근거 없는 예시는 null |
| PATCH 세트 후 이전 무게·횟수·version | 요청 반영 값과 version+1 |
| skipped 요청 응답 planned | status=skipped, 시작 잠금 없는 사례로 예시 구성 |
| 좋아요 DELETE 응답 liked_by_me=true | false, 삭제 후 실제 like_count |
| AI reply가 user 메시지와 같은 ID·역할·본문 | 고유 ID·assistant 역할·실제 답변 |
| replace 제안의 exercise=null | 검증된 운동 객체 필수. null은 remove에만 허용 |
| 제안 expires_at=created_at | 생성+24시간 |
| 대화 조회에 제안 정보 없음 | assistant suggestion 반환 |
| 댓글 parent_comment_id와 반환 parent 불일치 | 요청 parent와 반환 parent가 같고 새 댓글 ID는 별도 |
| 종목 등록 chest 요청·leg 응답 | 실제 저장된 요청 부위 반환 |
| 신고 resolved 요청·pending 응답 | 처리 후 상태 반환 |
| 삭제 회원에 email·nickname 남김 | null, 사용자 공개 표시는 탈퇴한 사용자 |
| 회원 탈퇴 DB 항목이 읽기만 | users·token_version·정리 작업 쓰기와 후속 삭제 명시 |

라이크·차단 DELETE는 대상 연결이 이미 없어도 성공하여 재전송에 안전해야 한다. 게시글·댓글 새 ID는 부모 ID나 예시 복사본을 재사용하지 않는다. 미션·쿠폰·푸시 예시도 시작/만료/발송 시각의 순서를 지킨다.
