> 현재 API 기준은 [팀장 API 명세](../api-baseline/README.md)입니다. 이 문서의 이전 제안과 충돌하면 최신 기준을 따릅니다.

# 데이터 모델 v1.1

원본 32개 테이블의 역할을 유지하되 상태·버전·참조·중복 방지를 보완한다. 아래는 구현 DDL이 아닌 논리 명세다. 제안 추가 테이블은 행 이름 뒤에 ‘추가’로 표시했다.

## 1. 공통 타입과 제약

- 모든 테이블은 별도 언급이 없으면 `id BIGINT PK`, `created_at DATETIME(3) NOT NULL`을 갖는다. 시각은 UTC 저장, 업무상 날짜는 Asia/Seoul로 계산한다. API ID는 JS 정밀도 문제를 피하도록 십진 문자열이다.
- 아래 `?`만 NULL 허용, 나머지는 NOT NULL이다. `UQ(a,b)`는 복합 유일성, `FK`는 실제 참조 무결성을 뜻한다. 사용자 소유 테이블은 `user_id BIGINT FK users.id`를 갖는다. 모든 FK는 BIGINT다.
- `str(n)=VARCHAR(n)`, `text=TEXT`, `json=JSON`, `bool=BOOLEAN`, `int=INT`, `date=DATE`, `time=TIME`, `ts=DATETIME(3)`, `dec=DECIMAL(10,3)`. 명시적 중량은 DECIMAL(6,1), 볼륨은 DECIMAL(12,1), 비율은 DECIMAL(8,4)를 사용한다.
- ENUM은 아래 기재된 영문 문자열만 허용한다. 화면 번역문을 DB enum에 넣지 않는다. BOOLEAN·카운터의 기본값은 아래 명시, 기타 필드는 자동으로 임의 기본값을 부여하지 않는다.
- 사용자 연결 테이블은 탈퇴 작업에서 삭제한다. 단순히 users.deleted_at만 설정하고 완료 처리하지 않는다. 마스터 데이터는 비활성화하고 참조 이력은 유지한다. 세부 삭제 규칙은 §4.
- 외부 API 요청으로 받은 user_id를 믿지 않고 인증 주체로 결정한다. 다른 사용자 소유 FK를 연결하지 못하도록 서버 트랜잭션에서 소유권을 검증한다.

## 2. 전체 테이블

### 회원과 인증

| 테이블 | 컬럼·타입 | 제약·설명 |
| --- | --- | --- |
| users | email str(255), password_hash str(255)?, nickname str(50), role enum(user,admin), account_status enum(active,deleting), profile_revision int default 0, allergy_revision int default 0, auth_version int default 1, active_analysis_id FK?, active_goal_body_id FK?, analysis_selected_at ts?, goal_selected_at ts?, timezone str(50) default Asia/Seoul, updated_at ts | UQ(email). 이메일 trim·소문자 정규화 후 중복 검사. active FK는 해당 사용자 완료 결과만 참조. survey_status는 프로필 존재로 계산하며 중복 저장하지 않음. selected_at은 명시적 선택·활성 전환 시 기록 |
| auth_identities (추가) | user_id FK, provider enum(google,kakao), provider_subject str(255) | UQ(provider,provider_subject), UQ(user_id,provider). users.provider/provider_id 대신 인증 수단 분리. 이메일 계정은 password_hash 존재로 판단 |
| auth_sessions (추가) | user_id FK, refresh_token_hash str(255), device_id str(100), expires_at ts, revoked_at ts?, rotated_from_id FK? | refresh hash UQ. 원문에 없던 refresh 상태 추가. 토큰 원문 미저장 |
| auth_challenges (추가) | user_id FK?, kind enum(password_reset,oauth_onboarding,reauth), token_hash str(255), payload_encrypted text?, expires_at ts, consumed_at ts? | token hash UQ. onboarding payload의 provider·subject·email은 짧은 기간 암호화 보관. 만료 후 정리 |
| user_profiles | user_id FK, height_cm DECIMAL(5,1), weight_kg DECIMAL(5,1), age SMALLINT, gender enum(male,female,unspecified), goal_type enum(bulk,cut,posture), weekly_frequency SMALLINT, experience_level enum(beginner,intermediate,experienced), activity_level enum(low,moderate,high), workout_days_json json, available_equipment_json json, updated_at ts | UQ(user_id). 요구사항 범위 CHECK. workout_days는 1~7 고유값이고 길이가 weekly_frequency와 같음. equipment는 none/dumbbell/barbell/machine/cable/band 허용 목록 |
| user_consents | user_id FK, consent_type enum(terms,privacy,body_photo,ai_processing), policy_version str(30), agreed bool, recorded_at ts | append-only. 최신 recorded_at,id가 현재 상태. 약관 버전별 변경 이력 유지 |
| user_allergies | user_id FK, kind enum(allergy,exclusion), item str(50), normalized_item str(50), updated_at ts | UQ(user_id,kind,normalized_item). 등록·수정·삭제 시 allergy_revision 증가 |
| admins | user_id FK, permission enum(super_admin,content_manager,partner_manager), updated_at ts | UQ(user_id). users.role=admin과 일치 검증. 관리자 생성은 일반 가입에서 불가 |

로그인 실패 횟수·요청 제한은 만료 가능한 키 저장소로 관리해도 된다. 이메일 정규화 키와 IP별 제한, 15분 만료를 적용한다. 별도 SQL 테이블이 필수인 것은 아니지만 단일 앱 메모리만으로 운영하지 않는다.

### 공통 작업과 사진·분석

| 테이블 | 컬럼·타입 | 제약·설명 |
| --- | --- | --- |
| jobs (추가) | user_id FK?, kind enum(body_analysis,goal_extract,goal_delete,comparison,routine_generate,diet_generate,chat,photo_delete,account_delete), status enum(queued,running,succeeded,failed,cancelled), input_json json?, result_type str(30)?, result_id BIGINT?, error_code str(80)?, started_at ts?, finished_at ts?, deadline_at ts, attempt_count int default 0, idempotency_key str(100), request_hash str(64), status_token_hash str(255)? | UQ(user_id,kind,idempotency_key) 접수 중복 방지. 탈퇴 job은 user FK 해제 후 개인정보 없는 결과만 유지. 결과의 다형 참조는 서비스가 검증 |
| photos | user_id FK, type enum(current,goal), view enum(front,side,reference), object_key str(500)?, state enum(available,processing,delete_pending,deleted), retention enum(persistent,temporary), mime str(30), byte_size int, width int, height int, expires_at ts?, deleted_at ts? | image_url 대신 비공개 object key. deleted이면 object_key=null. current는 front/side, goal은 reference만 허용. goal retention=temporary 강제 |
| body_analyses | user_id FK, job_id FK, method enum(photo,text), status enum(pending,done,failed,cancelled), text_input str(500)?, summary str(1000)?, focus_parts_json json?, features_json json?, posture_json json?, balance_score SMALLINT?, measurement_profile_id FK?, profile_snapshot_json json, profile_revision int, model_version str(100), completed_at ts? | job UQ. 점수 0~100 또는 null. photo는 연결 사진 최소 1개, text는 text_input 필수. done이어야 비교 입력 가능 |
| analysis_photos (추가) | analysis_id FK body_analyses, photo_id FK photos?, view enum(front,side), photo_deleted_at ts? | UQ(analysis_id,view). 사진 원본 삭제 후 참조 해제, view 기록 유지. 사진은 분석 사용자 소유 |
| measurement_profiles (추가) | version str(40), config_json json, validation_reference str(500), status enum(draft,validated,active,retired), validated_at ts? | version UQ. config에 landmark·관측 방향·오류 처리·신뢰도 하한·각도식·판정 경계·점수 산식. validated 근거 없으면 active 금지 |
| goal_bodies | user_id FK, revision int, job_id FK, photo_id FK photos?, description str(500)?, features_json json?, summary str(1000)?, status enum(pending,done,failed,cancelled), model_version str(100), completed_at ts? | UQ(user_id,revision), job UQ. 원본 삭제 시 photo_id=null, features는 유지. 사용 중 목표는 users.active_goal_body_id로 선택 |
| body_comparisons | user_id FK, current_analysis_id FK, goal_body_id FK?, goal_revision int, profile_revision int, priority_parts_json json, comparison_features_json json, summary str(1000), goal_snapshot_json json, rule_version str(40) | 입력 결과 immutable. goal 삭제 후 과거 요약 snapshot 유지. 사진 원본·URL은 snapshot에 금지 |

### 운동과 추천 수정

| 테이블 | 컬럼·타입 | 제약·설명 |
| --- | --- | --- |
| exercises | name str(50), target_part enum(shoulders,back,chest,core,arms,glutes,legs), difficulty enum(beginner,intermediate,advanced), equipment enum(none,dumbbell,barbell,machine,cable,band), instructions text, active bool default true, updated_at ts | 과거 기록에 연결된 종목은 물리 삭제 금지. 원본 min/max_sets는 아래 경력별 처방으로 이동 |
| exercise_prescriptions (추가) | exercise_id FK, experience_level enum(beginner,intermediate,experienced), min_sets SMALLINT, max_sets SMALLINT, min_reps SMALLINT, max_reps SMALLINT, min_rest_sec SMALLINT, max_rest_sec SMALLINT, min_weight_kg DECIMAL(6,1)?, max_weight_kg DECIMAL(6,1)?, seconds_per_rep dec default 3, version int, active bool default true | UQ(exercise_id,experience_level,version). 사용자 경력에 활성 처방 1개. 각 min≤max. 중량 두 필드는 둘 다 null 또는 둘 다 값. null이면 숫자 추천 금지 |
| routines | user_id FK, comparison_id FK, week_start date, version int, status enum(active,superseded,expired), input_snapshot_json json, profile_revision int, goal_revision int, source enum(generation,ai_suggestion), parent_routine_id FK?, estimated_duration_sec int | UQ(user_id,week_start,version), 사용자·주별 active 1개를 잠금/생성 키로 강제. week_start 월요일 |
| routine_items | routine_id FK, exercise_id FK, day_of_week SMALLINT, sort_order SMALLINT, target_sets SMALLINT, target_reps SMALLINT, rest_sec SMALLINT, target_weight_min DECIMAL(6,1)?, target_weight_max DECIMAL(6,1)?, estimated_duration_sec int, prescription_version int | UQ(routine_id,day_of_week,sort_order). 요일 1~7, 세트·반복 양수. 중량 범위는 처방 내 |
| workout_logs | user_id FK, routine_id FK?, workout_date date, status enum(in_progress,paused,completed,aborted), started_at ts, ended_at ts?, paused_at ts?, paused_duration_sec int default 0, duration_sec int?, active_duration_sec int?, total_volume_kg DECIMAL(12,1) default 0, version int default 1 | 열린 세션 사용자당 1개. workout_date=시작 시 현지 날짜, 자정 넘어도 시작일로 귀속. 완료 후 immutable |
| workout_log_items (추가) | log_id FK, exercise_id FK, source_routine_item_id FK?, sort_order SMALLINT, prescription_snapshot_json json | UQ(log_id,sort_order). 같은 종목의 별개 블록을 구분하는 세션 항목 ID |
| workout_sets | log_item_id FK, client_set_id str(36), set_no SMALLINT, weight_kg DECIMAL(6,1), reps SMALLINT, is_done bool default false, completed_at ts?, version int default 1, updated_at ts | UQ(log_item_id,client_set_id), UQ(log_item_id,set_no). log와 exercise는 log_item으로 얻음. 삭제 시 재번호는 서버가 정렬 순서 보존하며 트랜잭션 처리 |
| correction_exercises | target_issue enum(shoulder_asymmetry,forward_neck,pelvis_asymmetry), name str(50), method text, duration_sec int?, reps SMALLINT?, sets SMALLINT, active bool default true, updated_at ts | duration_sec 또는 reps 중 하나 이상. 활성 판정 항목마다 2~3개가 준비되어야 제공 가능 |
| routine_suggestions (추가) | user_id FK, chat_message_id FK, base_routine_id FK, base_version int, proposed_items_json json, reason str(1000), status enum(pending,accepted,rejected,expired), expires_at ts, applied_routine_id FK?, decided_at ts? | 24시간 만료. accepted에는 applied_routine_id 필수. 동일 제안 한 번만 적용, 승인 트랜잭션에서 원본 활성 버전 검증 |

열린 세션·활성 처방·활성 루틴의 조건부 유일성은 DB 선택에 맞춰 nullable 생성 컬럼의 UNIQUE 또는 별도 활성 포인터+부모 행 잠금으로 구현한다. 단순 ‘조회 후 insert’만으로는 동시성 제약을 충족하지 않는다.

### 식단과 상품

| 테이블 | 컬럼·타입 | 제약·설명 |
| --- | --- | --- |
| nutrition_profiles (추가) | version str(40), calculation_config_json json, validation_reference str(500), status enum(draft,validated,active,retired), validated_at ts? | version UQ. 입력 지원 범위·열량·영양소 함수·반올림·허용 오차·성별 미지정 경로 명시. 근거 검증 전 active 금지 |
| foods (추가) | name str(100), unit_grams DECIMAL(7,2), kcal dec, protein_g dec, carb_g dec, fat_g dec, ingredients_json json, allergens_json json, source_reference str(500), verified bool default false, active bool default true, updated_at ts | 영양소는 unit_grams 기준. 성분 미검증 식품은 알레르기 맞춤 생성에 사용 불가 |
| diet_plans | user_id FK, comparison_id FK, plan_date date, version int, status enum(active,superseded), target_kcal int, protein_g dec, carb_g dec, fat_g dec, reason str(1000), nutrition_profile_id FK, input_snapshot_json json, profile_revision int, allergy_revision int, goal_revision int | UQ(user_id,plan_date,version), 사용자·날짜별 active 1개. 입력 revision과 활성 리소스로 stale 계산 |
| diet_meals | plan_id FK, meal_type enum(breakfast,lunch,snack,dinner), time time, menu str(255), kcal dec, protein_g dec, carb_g dec, fat_g dec, sort_order SMALLINT | UQ(plan_id,meal_type), UQ(plan_id,sort_order). 합산은 food snapshots로 재현 |
| diet_meal_items (추가) | meal_id FK, food_id FK, quantity_units dec, food_snapshot_json json | 수량>0. 이름·영양·성분·기준량 snapshot, 마스터 변경이 과거 식단을 바꾸지 않음 |
| partners | name str(100), contract_start date, contract_end date, active bool default true, updated_at ts | 시작≤종료. 계약 종료 시 새 상품 노출·미션 배정 제외 |
| partner_products | partner_id FK, category enum(protein,chicken_breast,meal,other), name str(100), nutrition_json json?, ingredients_json json?, allergens_json json?, ingredients_verified bool default false, link_url str(500), display_from date, display_to date, active bool default true, updated_at ts | is_ad_labeled 제거. API ad_label 고정값 ‘광고·제휴’. URL https 허용, 유효 기간·계약 기간 동시 충족 |

### 미션과 쿠폰

| 테이블 | 컬럼·타입 | 제약·설명 |
| --- | --- | --- |
| missions | title str(100), condition_json json, coupon_id FK, active bool default false, updated_at ts | v1 주간만 지원하므로 period_days=7은 계약 상수. 쿠폰 재고·유효 계약 없으면 활성화 불가 |
| user_missions | user_id FK, mission_id FK, period_start date, period_end date, condition_snapshot_json json, status enum(in_progress,succeeded,failed), qualified_days SMALLINT default 0, completed_at ts? | UQ(user_id,period_start), 기간은 월~일. progress는 count/target으로 계산해 중복 진실값 미저장 |
| mission_credits (추가) | user_mission_id FK, workout_date date, log_id FK | UQ(user_mission_id,workout_date), 동일 일 1회. completed·600초 이상·완료 세트 존재를 검증 |
| coupons | partner_id FK, title str(100), discount_desc str(255), valid_days SMALLINT, redemption_url str(500), instructions text, active bool default false, updated_at ts | valid_days 1~365. 실제 코드 공급 후 활성화 |
| coupon_codes (추가) | coupon_id FK, code_encrypted text, code_hash str(64), state enum(available,reserved,issued), reserved_user_mission_id FK?, issued_user_coupon_id FK? | UQ(coupon_id,code_hash), reservation과 issued link 각각 UQ. 예약·발급·반환은 잠금 트랜잭션 |
| user_coupons | user_id FK, coupon_id FK, user_mission_id FK, coupon_code_id FK, benefit_snapshot_json json, issued_at ts, expires_at ts, used_at ts?, usage_source enum(self_report,partner_verified)? | UQ(user_mission_id), UQ(coupon_code_id). v1 API는 self_report만 지원. 목록에는 코드 원문 미노출 |

### 채팅과 커뮤니티

| 테이블 | 컬럼·타입 | 제약·설명 |
| --- | --- | --- |
| chat_messages | user_id FK, request_job_id FK, sender enum(user,ai), content text, status enum(pending,done,failed), reply_to_id FK?, model_version str(100)?, context_refs_json json? | UQ(request_job_id,sender). 질문 1~2000자. AI 본문 최대 8000자. 실패 질문도 이력에 표시, 원본 사진 URL은 context에 넣지 않음 |
| ai_daily_usage (추가) | user_id FK, usage_date date, reserved_count int default 0, completed_count int default 0, updated_at ts | UQ(user_id,usage_date), 각 값≥0, 합≤30. job과 함께 원자적 예약·환원 |
| posts | user_id FK, category enum(information,certification,question), title str(50), content str(2000), moderation_status enum(visible,hidden,deleted), like_count int default 0, updated_at ts | 실제 like 수와 캐시 동기화. deleted는 본문·이미지 삭제 후 최소 상태만 유지 가능, 탈퇴 때 전체 제거 |
| post_images | post_id FK, photo_asset_id FK, sort_order SMALLINT | UQ(post_id,sort_order), 1~4. 체형 사진과 저장 목적 분리 |
| community_assets (추가) | user_id FK, object_key str(500)?, state enum(unattached,attached,delete_pending,deleted), mime str(30), byte_size int, expires_at ts?, attached_post_id FK? | 미첨부 업로드 1시간 후 삭제. 다른 사용자의 업로드 연결 금지. 연결 해제 이미지 즉시 삭제 작업 |
| comments | post_id FK, user_id FK, content str(500), moderation_status enum(visible,hidden,deleted), updated_at ts | 게시글 삭제 시 댓글도 삭제. 숨김은 API 일반 조회에서 제외 |
| post_likes | post_id FK, user_id FK | UQ(post_id,user_id). 생성·삭제와 like_count 갱신 동일 트랜잭션 |
| reports | reporter_id FK users, post_id FK?, comment_id FK?, reason enum(spam,abuse,inappropriate,misinformation,other), detail str(500)?, status enum(pending,resolved,dismissed), resolved_at ts?, resolved_by_admin_id FK? | post_id/comment_id 정확히 하나만 값. UQ(reporter_id,post_id), UQ(reporter_id,comment_id). target_type/target_id는 API 표현만 사용 |
| user_blocks | user_id FK, blocked_user_id FK users | UQ(user_id,blocked_user_id), 자기 차단 금지 |
| admin_actions (추가) | admin_id FK?, action str(80), target_type str(40), target_id BIGINT?, reason str(1000), metadata_json json? | 보존할 개인정보 없는 최소 감사 기록. 원문 본문·사진·이메일 snapshot 금지 |

### 연속 기록·알림·요청 중복

| 테이블 | 컬럼·타입 | 제약·설명 |
| --- | --- | --- |
| user_streaks | user_id FK, current_streak int default 0, longest_streak int default 0, last_workout_date date?, calculated_at ts | UQ(user_id). workout_logs에서 재생성 가능한 캐시. 휴식일 정책은 요구사항 §5 |
| notification_settings | user_id FK, type enum(workout,diet,streak_risk), enabled bool default false, time time, updated_at ts | UQ(user_id,type). 최초 설정 3개 생성. 원본 true 기본값은 권한·사용자 선택 전 발송 방지를 위해 false로 제안 변경 |
| user_devices (추가) | user_id FK, device_id str(100), platform enum(android,ios), push_token_encrypted text?, token_hash str(64)?, push_enabled bool default false, last_seen_at ts | UQ(user_id,device_id), token_hash UQ. 로그아웃 시 해당 기기 토큰 연결 해제 |
| notification_deliveries (추가) | user_id FK, local_date date, type enum(workout,diet,streak_risk), status enum(scheduled,sent,cancelled,failed), scheduled_at ts, sent_at ts?, dedupe_key str(100) | UQ(user_id,local_date), dedupe key UQ. 같은 전달 ID로 기기 fan-out, 재시도 시 추가 일일 슬롯 생성 금지 |
| idempotency_requests (추가) | user_id FK, scope str(100), key str(100), request_hash str(64), status enum(processing,completed), response_code int?, response_json json?, expires_at ts | UQ(user_id,scope,key), 24시간 유지. 세션 생성·세트 추가·승인·종료·쿠폰 사용에 적용. 사용자 탈퇴 시 제거 |
| deletion_tombstones (추가) | subject_key_hash str(64), deleted_at ts, backup_expires_at ts | UQ(subject_key_hash). 백업 복구 시 삭제를 재적용할 최소 키. 원문 개인정보·사진·결과 보관 금지. 백업 만료 후 삭제 |

## 3. 공통 JSON 계약

모든 JSON은 schema_version=1을 갖는다. 허용되지 않은 키·enum은 생성 단계에서 거부한다. null은 미측정이며 0과 다르다. 아래는 저장·응답 계약 예시이며 모델이 자유롭게 구조를 바꾸지 못한다.

### features_json

```json
{
  "schema_version": 1,
  "source": "photo",
  "ratios": {
    "shoulder_hip_ratio": {"value": 1.2, "basis": "observed", "reason": null},
    "torso_leg_ratio": {"value": null, "basis": "unavailable", "reason": "OCCLUDED"}
  },
  "focus_parts": [{"part": "back", "basis": "user_stated", "description": "등 운동에 집중하고 싶음"}],
  "limitations": ["IMAGE_SPACE_RATIO"]
}
```

source=photo/text/mixed, ratio basis=observed/unavailable, focus basis=user_stated/inferred. 글에서 비율을 추정하여 observed로 저장하지 않는다. 사진에서 보이는 선호 스타일의 분류는 inferred로만 기록하고 실제 근육량으로 표현하지 않는다. 값 1.2는 형식 예시이며 정상 기준이 아니다.

### posture_json

```json
{
  "schema_version": 1,
  "metrics": [
    {"key": "shoulder_asymmetry", "angle_deg": 2.0, "assessment": "unavailable", "reason": "PROFILE_NOT_VALIDATED", "view": "front"},
    {"key": "forward_neck", "angle_deg": null, "assessment": "unavailable", "reason": "SIDE_PHOTO_MISSING", "view": "side"}
  ],
  "balance_score": null,
  "measurement_version": "draft-v1"
}
```

metrics에는 shoulder_asymmetry/forward_neck/pelvis_asymmetry 3개 키를 항상 반환한다. assessment=good/caution/unavailable. 판정 미검증이면 관측 각도는 제공 가능하지만 good/caution과 점수는 제공하지 않는다. 출시용 profile은 별도 검증 게이트를 통과해야 한다.

### priority_parts_json과 comparison_features_json

```json
{
  "schema_version": 1,
  "items": [
    {"part": "back", "rank": 1, "basis": "preference", "evidence": "현재 고민과 목표 설명에서 등 운동을 우선 요청", "recommendation": "등 부위 운동을 주간 루틴에 배분"}
  ],
  "limitations": ["NO_COMPARABLE_RATIO"]
}
```

part는 공통 부위 enum, rank는 1부터 중복 없이 연속, basis=measured/preference/mixed. comparison_features_json은 `{schema_version,items:[{key,current_value,goal_value,delta,comparable,reason}]}`이며 delta=goal-current, 비교 불가 시 값·delta는 null. 기존 ‘등 두께 차이’처럼 측정 근거 없는 표현은 출력 금지.

### 미션·영양·수정안

- condition_json: `{schema_version:1,type:"weekly_workout_days",target_days:3,min_active_seconds:600,min_completed_sets:1,daily_cap:1}`. target_days만 사용자 프로필에 따라 2 또는 3으로 snapshot 생성한다.
- nutrition_json: `{schema_version:1,serving_grams:100,kcal:120,protein_g:20,carb_g:5,fat_g:2,source:"제공 자료 식별자"}`. 비음수, serving_grams>0. 수치는 스키마 예시다.
- proposed_items_json: `{schema_version:1,items:[{day_of_week,sort_order,exercise_id,target_sets,target_reps,rest_sec,target_weight_min,target_weight_max}],effective_from_date}`. routine_items와 같은 검증을 통과해야 승인 가능.
- input_snapshot_json: 입력 프로필·revision·알레르기·분석/목표/비교 ID·규칙/모델 버전. 비밀번호·토큰·원본 URL은 금지.
- benefit_snapshot_json: `{schema_version:1,title,partner_name,discount_desc,redemption_url,instructions,valid_days}`. 실제 쿠폰 코드는 coupon_codes에서 소유자 상세 조회 시에만 복호화한다.

## 4. 삭제와 변경 규칙

| 대상 | 처리 |
| --- | --- |
| 현재·목표 사진 원본 | 접근 차단 → 저장소 원본/파생 파일 삭제 확인 → analysis_photos.photo_id와 goal_bodies.photo_id null → photo 삭제 상태 유지. 결과 수치는 보존 |
| 목표 전체 삭제 | 활성 포인터 해제, 진행 goal job 취소, 목표 사진 삭제, comparison.goal FK null, 목표 revision 제거. 기존 요약은 유지·현재 추천 stale |
| 루틴·운동 마스터 수정 | 과거 루틴 버전과 운동 snapshot 변경 금지. 마스터 비활성화는 새 추천에서만 제외 |
| 게시글·댓글 삭제 | 공개 접근 차단, 본문·이미지 제거, 관리자 조치·신고에 필요한 상태만 유지. 탈퇴에서는 관련 row까지 정리 |
| 프로필·알레르기 수정 | 입력 revision 증가, 기존 snapshot immutable, 새로운 알레르기와 충돌하는 식단 노출 차단 |
| 탈퇴 | 활성 FK 먼저 해제, job 취소·접근 차단, 객체 삭제 후 사용자 소유 데이터·교차 likes/blocks/reports FK 정리, user 마지막 삭제. audit actor null. 실패 시 재시도 가능해야 함 |
| 제휴 계약 만료 | 새 노출·배정 중단. 이미 발급한 혜택 snapshot 유지, 실제 사용 가능 여부는 발급 당시 계약 조건 준수 |

원형 FK(users.active_analysis_id, coupon_codes.issued_user_coupon_id 등)는 생성 때 null로 두고 같은 트랜잭션의 후속 갱신으로 연결한다. 참조 삭제 순서를 마이그레이션·삭제 작업에서 명시하고 무조건 CASCADE로 전체 이력을 지우지 않는다.

## 5. 주요 인덱스

users(email), auth_identities(provider,provider_subject), jobs(user_id,status,created_at), photos(user_id,state,type), body_analyses(user_id,completed_at,id), goal_bodies(user_id,revision), routines(user_id,week_start,status), workout_logs(user_id,workout_date,status), workout_sets(log_item_id,set_no), diet_plans(user_id,plan_date,status), user_missions(user_id,period_start), user_coupons(user_id,expires_at), chat_messages(user_id,created_at,id), posts(category,moderation_status,created_at,id), comments(post_id,moderation_status,created_at,id), reports(status,created_at), notification_deliveries(status,scheduled_at).

각 UQ도 인덱스다. 실제 실행 계획을 확인하기 전 불필요한 중복 인덱스는 만들지 않는다.
