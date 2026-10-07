> 현재 API 기준은 [팀장 API 명세](../api-baseline/README.md)입니다. 이 문서의 이전 제안과 충돌하면 최신 기준을 따릅니다.

# API 계약 v1.1

모든 경로는 `/api/v1` 기준 상대 경로다. 원본 API의 중복 항목은 제거하고 필요한 후속 동작을 추가했다. 서버 코드를 작성한 결과가 아닌 FE·BE·AI 합의용 계약이다.

## 1. 공통 규칙

- 기본 인증: `Authorization: Bearer <access_token>`. 공개 API는 표에서 public 표시. admin API는 역할과 세부 permission을 함께 검증한다.
- ID는 십진 문자열, 정수는 JSON number, decimal은 JSON number, bool은 boolean. 시각은 UTC RFC3339 문자열, 날짜는 `YYYY-MM-DD`, 시간은 `HH:mm:ss`. 업무 날짜는 Asia/Seoul. `?`는 선택 입력/nullable 출력, `[]`는 배열이다.
- JSON 요청은 `application/json`. 사진·커뮤니티 파일은 `multipart/form-data`. 문서의 입력 목록은 기본 body이며 `q:`는 query, `path:`는 경로 변수다. path 변수는 모두 필수 ID, `{type}`·`{provider}`만 해당 enum이다.
- `PageQ`: page int≥1 default 1, page_size int 1~100 default 20. `DateRangeQ`: start_date·end_date date 선택, 기본 최근 30일, 시작≤종료, 최대 366일. `WeekQ`: week_start date 선택, 기본 이번 주 월요일, 월요일만 허용.
- 모든 텍스트는 trim 후 길이 검증. 길이는 Unicode code point 수. 알 수 없는 필드·enum은 422. 목록은 기본 created_at,id 내림차순, 운동 항목은 day_of_week,sort_order 오름차순.
- 일반 생성 201, 조회·수정·동작 200, 본문 없는 삭제 204, 비동기 접수 202. 작업 조회 자체가 성공했으면 job.status=failed여도 HTTP 200이다.
- 사용자 소유 객체가 없거나 다른 사용자 객체면 동일 404. 관리 권한 부족은 403. 공개 리소스가 아니면 인증 없이 접근 불가.
- `Idempotency-Key`는 모든 비동기 생성, 운동 시작·세트 추가·종료, AI 승인, 쿠폰 사용 처리, 탈퇴에서 필수 UUID. 동일 요청은 24시간 같은 결과, 같은 키에 다른 body는 409. 장기 중복 방지는 DB 유일성·도메인 상태로 유지한다.
- PATCH는 명시한 필드만 변경한다. nullable 필드만 null로 지울 수 있다. 빈 PATCH는 422. 운동 PATCH는 `version` 필수, 불일치 시 409.
- 사진 URL은 비공개 object key가 아닌 5분 이내 만료 signed URL. 삭제 요청 후에는 신규 URL 발급 금지와 기존 접근 철회가 가능한 전달 계층을 사용한다. 즉시 철회 불가능한 저장소 URL만으로 요구사항을 충족했다고 간주하지 않는다.

### 응답 envelope

```json
{"data":{"id":"123"},"meta":{"request_id":"req_example"}}
```

페이지 응답: `data`는 배열, `meta={request_id,page,page_size,total_count,has_next}`. 비페이지 목록은 배열만 반환한다. 오류:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "입력값을 확인해 주세요.",
    "fields": [{"field":"height_cm","reason":"OUT_OF_RANGE"}],
    "retryable": false
  },
  "meta": {"request_id":"req_example"}
}
```

FE는 code로 분기하고 message 문자열에 의존하지 않는다. enum은 데이터 모델과 동일하다. 오류 fields는 오류별로 생략 가능하다.

## 2. 요청·응답 타입

### 요청 타입

| 타입 | 필드 |
| --- | --- |
| ConsentInput | type enum(terms,privacy,body_photo,ai_processing), policy_version string, agreed bool |
| SignupInput | email string, password string, nickname string, consents ConsentInput[]; 현재 필수 약관 2종 true 필요 |
| ProfileInput | height_cm number, weight_kg number, age int, gender enum, goal_type enum, weekly_frequency int, experience_level enum, activity_level enum, workout_days int[]?, available_equipment enum[]; 범위는 요구사항 REQ-005, workout_days 생략 시 기본 배분 |
| AllergyInput | kind enum(allergy,exclusion), item string 1~50 |
| AnalysisPhotoInput | front_photo_id ID, side_photo_id ID?; current·해당 view·available 본인 사진만 |
| GoalInput | photo_id ID?, description string 1~500?; 하나 이상. 사진은 goal/reference |
| SetCreateInput | log_item_id ID, client_set_id UUID, weight_kg number 0~500, reps int 1~200, is_done bool default false; set_no는 서버가 마지막 순번 다음으로 부여 |
| SetPatchInput | version int, weight_kg number?, reps int?, is_done bool? |
| PostInput | category enum, title string 1~50, content string 1~2000, image_asset_ids ID[] 최대 4 |
| ProductInput | partner_id ID, category enum, name string 1~100, nutrition_json object?, ingredients_json array?, allergens_json array?, ingredients_verified bool, link_url HTTPS URL, display_from date, display_to date, active bool |
| MissionInput | title string 1~100, condition_json object(데이터 §3), coupon_id ID, active bool |
| CouponInput | partner_id ID, title string 1~100, discount_desc string 1~255, valid_days int 1~365, redemption_url HTTPS URL, instructions string 1~5000, active bool |
| ExerciseInput | name string 1~50, target_part enum, difficulty enum, equipment enum, instructions string 1~5000, active bool |
| PrescriptionInput | experience_level enum, min_sets/max_sets int 1~20, min_reps/max_reps int 1~200, min_rest_sec/max_rest_sec int 15~600, min_weight_kg/max_weight_kg number? 0~500, seconds_per_rep number 1~10; min≤max, 중량 둘 다 null 또는 값 |
| CorrectionInput | target_issue enum, name string 1~50, method string 1~5000, duration_sec int? 1~3600, reps int? 1~200, sets int 1~20, active bool; duration 또는 reps 필수 |

`Patch<T>`는 위 타입의 변경 가능한 모든 필드가 선택인 객체다. ID·소유자·생성 시각은 변경 불가. 예외는 API 표에 명시한다. 프로필 변경은 수정 후 전체 데이터가 유효해야 하며 빈도 변경 후 요일 수 불일치면 422를 반환한다.

### 공개 응답 타입

아래 목록이 공개 필드의 허용 목록이다. DB entity 전체 직렬화는 금지한다. `id`, `created_at`은 해당 리소스에 공통으로 포함하며 Aggregate 타입에는 별도 지정 없으면 포함하지 않는다. JSON 내부 구조는 데이터 모델 §3에 따른다.

| 타입 | data 필드 |
| --- | --- |
| AuthResult | access_token, access_expires_in=900, refresh_token, refresh_expires_in=2592000, user:User |
| User | id,email,nickname,role,survey_status(pending/completed),setup_state,profile_revision,allergy_revision,active_analysis_id?,active_goal_body_id?,capabilities string[],created_at |
| ConsentPolicy | type,version,title,content_url,required_for_signup bool |
| Consent | type,policy_version,agreed,recorded_at |
| Profile | id,ProfileInput의 모든 필드,revision,updated_at |
| Allergy | id,kind,item,created_at |
| Photo | id,type,view,state,retention,url?,url_expires_at?,expires_at?,created_at |
| JobAccepted | job_id,status,resource_type?,resource_id?,poll_after_ms=2000,status_url |
| Job | id,kind,status,result:{type,id}?,error:{code,message,retryable}?,created_at,started_at?,finished_at?,poll_after_ms? |
| Analysis | id,method,status,text_input?,summary?,focus_parts?,features?,posture?,balance_score?,measurement_version?,completed_at?,created_at |
| Goal | id,revision,status,description?,summary?,features?,is_active bool,created_at,completed_at?; 목표 원본 URL은 반환하지 않음 |
| Comparison | id,current_analysis_id,goal_body_id?,priority_parts,comparison_features,summary,stale bool,stale_reasons string[],created_at |
| Exercise | id,name,target_part,difficulty,equipment,instructions |
| Prescription | id,exercise_id,PrescriptionInput 필드,version,active |
| RoutineItem | id,exercise:Exercise,day_of_week,sort_order,target_sets,target_reps,rest_sec,target_weight_min?,target_weight_max?,estimated_duration_sec |
| Routine | id,comparison_id,week_start,version,status,stale,stale_reasons,estimated_duration_sec,items:RoutineItem[],created_at |
| TodayRoutine | date,is_rest_day,routine:Routine?,items:RoutineItem[],estimated_duration_sec,day_status(rest/planned/in_progress/completed) |
| WorkoutSet | id,log_item_id,client_set_id,set_no,weight_kg,reps,is_done,completed_at?,version |
| WorkoutItem | id,exercise:Exercise,sort_order,prescription_snapshot,sets:WorkoutSet[] |
| WorkoutLog | id,routine_id?,workout_date,status,started_at,ended_at?,paused_at?,duration_sec?,active_duration_sec?,total_volume_kg,version,items:WorkoutItem[],mission_qualified bool |
| WorkoutSummary | id,routine_id?,workout_date,status,duration_sec?,active_duration_sec?,total_volume_kg |
| WorkoutStats | start_date,end_date,completed_sessions,workout_days,weekly:[{week_start,workout_days}],personal_bests:[{exercise_id,name,weight_kg,achieved_on}] |
| Correction | id,target_issue,name,method,duration_sec?,reps?,sets |
| CorrectionPlan | analysis_id,items:[{issue,assessment,reason?,exercises:Correction[]}] |
| Meal | id,meal_type,time,menu,kcal,protein_g,carb_g,fat_g,items:[{food_id,name,quantity_units,grams}] |
| DietPlan | id,comparison_id,plan_date,version,stale,stale_reasons,target_kcal,protein_g,carb_g,fat_g,macro_energy_percent:{protein,carb,fat},reason,meals:Meal[],created_at |
| Product | id,category,name,partner_name,nutrition?,link_url,ad_label="광고·제휴",match_reason? |
| MissionProgress | id,user_mission_id,title,period_start,period_end,status,qualified_days,target_days,progress_percent,reward_title,reward_state(reserved/issued/released),user_coupon_id? |
| CurrentMission | current:MissionProgress?,next_eligible_date?,unavailable_reason? |
| CouponSummary | id,title,partner_name,discount_desc,issued_at,expires_at,status,used_at?,usage_source? |
| UserCoupon | CouponSummary 모든 필드,code,redemption_url,instructions; 본인 상세에만 code 반환 |
| ChatMessage | id,sender,content,status,created_at,suggestion_id? |
| Suggestion | id,base_routine_id,base_version,status,reason,proposed_items,effective_from_date,expires_at,applied_routine_id? |
| AiUsage | date,limit=30,used,reserved,remaining,reset_at |
| PostSummary | id,category,title,author:{id,nickname},like_count,comment_count,liked_by_me,created_at,updated_at |
| Post | PostSummary 필드,content,images:[{asset_id,url,sort_order}] |
| Comment | id,post_id,author:{id,nickname},content,created_at |
| CommunityAsset | id,url,url_expires_at,expires_at,state |
| Report | id,target_type,target_id,reason,detail?,status,created_at |
| Block | user_id,nickname,created_at |
| Streak | current_streak,longest_streak,last_workout_date?,as_of_date,weekly_plan:{planned_days,completed_days,completion_percent} |
| NotificationSetting | type,enabled,time |
| Home | date,setup_state,active_jobs:JobAccepted[],today:TodayRoutine,current_workout:WorkoutSummary?,streak:Streak,diet_status(empty/generating/ready/stale/failed),mission:CurrentMission,mascot:{state,message_key},needs_reanalysis bool |

관리 리소스 응답은 데이터 모델의 해당 마스터 필드+id,created_at,updated_at이다. 비밀값(code 원문·해시·암호화값·토큰·object key), 사용자 snapshot은 관리 응답에서도 반환하지 않는다. 회원 관리 응답은 User와 account_status만 포함한다. Page<T>는 공통 페이지 envelope, List<T>는 이 문서 관리자 표에서 Page<T>의 별칭이다. Partner=partners, ProductAdmin=partner_products, MissionDefinition=missions, CouponDefinition=coupons, ExerciseAdmin=exercises, CorrectionAdmin=correction_exercises의 위 허용 정책을 적용한 표현이다.

## 3. 비동기 작업

상태 전이: queued → running → succeeded/failed/cancelled. terminal 상태는 바뀌지 않는다. 재시도는 새 job을 생성한다. 결과가 늦게 도착해도 failed/cancelled job의 결과를 활성화하지 않는다.

사진·글 분석과 목표 특징 추출은 접수부터 60초, 비교·루틴·식단 생성·채팅은 120초 deadline. 사진 분석의 p95 10초는 별도 성능 목표다. 삭제 작업은 최대 24시간 목표로 재시도하고 초과 시 운영 경보를 발생시킨다. 삭제 작업을 실패 후 방치하지 않는다.

FE는 2초 간격 조회로 시작하고 10초 이후 5초 간격, 백그라운드에서는 중단한다. 재실행 시 active_jobs로 이어간다. 사용자 재시도는 이전 요청의 timeout 여부를 확인하고 새 키를 사용한다. 목표의 임시 사진이 삭제됐다면 재업로드해야 한다.

| Method | URL | 입력 | 결과 |
| --- | --- | --- | --- |
| GET | /jobs/{job_id} | path job_id | Job |
| GET | /jobs | q status enum[]?, PageQ | Page<Job> 본인 작업 |
| POST | /jobs/{job_id}/cancel | 없음 | Job; AI 생성만 취소 가능, 삭제 작업 취소 불가 |

예시 흐름: 사진 업로드 → 분석 POST 202 → GET job → succeeded.result.id로 분석 GET. 루틴·식단 등도 같은 방식이다. job.error.code는 공통 오류 코드와 같다.

## 4. 인증·설문·홈

| Method | URL | 입력 | 결과·조건 |
| --- | --- | --- | --- |
| GET | /consent-policies | public | ConsentPolicy[] 현재 버전 |
| POST | /users | public, SignupInput | 201 AuthResult |
| POST | /auth/login | public, email string,password string | AuthResult |
| POST | /auth/refresh | public, refresh_token string | AuthResult; refresh 회전, 재사용 감지 시 같은 세션 계열 폐기 |
| POST | /auth/logout | refresh_token string? | 204; 현재 세션 폐기, 앱 토큰 제거 |
| POST | /auth/password/reset-request | public, email string | 202 {accepted:true}; 이메일 존재 노출 금지 |
| PATCH | /auth/password/reset | public, token string,new_password string | {changed:true}; 토큰 1회 사용 |
| POST | /auth/oauth/{provider} | public, provider=google/kakao, authorization_code string,redirect_uri string,code_verifier string? | {status:"authenticated",auth:AuthResult} 또는 {status:"onboarding_required",onboarding_token,expires_in:600}; provider 설정에 맞는 redirect allowlist·PKCE 검증 |
| POST | /auth/oauth/complete | public, onboarding_token string,nickname string,consents ConsentInput[] | 201 AuthResult; 한 번만 소비 |
| POST | /auth/reauth | password string? 또는 provider enum?,authorization_code string?,redirect_uri string?,code_verifier string? | {reauth_token,expires_in:300}; 현재 사용자와 재인증 주체 일치 |
| GET | /users/me | 없음 | User |
| PATCH | /users/me | nickname string 2~50 | User |
| GET | /users/me/consents | 없음 | Consent[] 최신 상태 |
| POST | /users/me/consents | consents ConsentInput[] | Consent[]; body_photo·ai_processing 철회 지원, 필수 약관 철회는 탈퇴 흐름 안내 |
| DELETE | /users/me | reauth_token string,confirmation string="DELETE" | 202 {job_id,status_token,status_url}; 토큰 즉시 무효화 |
| GET | /account-deletions/{job_id} | public, Authorization: Deletion <status_token> | {status,requested_at,completed_at?}; 개인정보 미포함, 7일 유효 |
| POST | /users/me/profile | ProfileInput | 201 Profile; 기존 프로필 있으면 409 |
| GET | /users/me/profile | 없음 | Profile; 미등록 404 |
| PATCH | /users/me/profile | Patch<ProfileInput> | Profile, revision 증가 |
| GET | /users/me/allergies | 없음 | Allergy[] |
| POST | /users/me/allergies | AllergyInput | 201 Allergy; 중복이면 409 |
| PATCH | /users/me/allergies/{allergy_id} | Patch<AllergyInput> | Allergy |
| DELETE | /users/me/allergies/{allergy_id} | 없음 | 204 |
| GET | /home | q date date? default 오늘 | Home |

access token 15분, refresh 30일은 제안 기본값. 서버는 access 검증 시 users.auth_version·account_status와 해당 로그인 세션의 폐기 여부를 확인해 탈퇴·로그아웃을 즉시 반영한다. JWT 서명만 확인하는 구현은 이 계약과 다르다.

## 5. 사진·분석·목표·비교

| Method | URL | 입력 | 결과·조건 |
| --- | --- | --- | --- |
| POST | /photos | multipart image file,type enum(current,goal),view enum(front,side,reference) | 201 Photo, 이미지 방향 보정·메타데이터 제거 |
| GET | /photos | q type enum?,PageQ | Page<Photo>; 삭제 중·삭제 완료 제외 |
| DELETE | /photos/{photo_id} | 없음 | 202 JobAccepted; 참조 중 AI 작업 취소 |
| DELETE | /photos | q type enum(current,goal,all) default all | 202 JobAccepted |
| POST | /body-analyses/photo | AnalysisPhotoInput | 202 JobAccepted, resource_type=analysis |
| POST | /body-analyses/text | text_input string 1~500 | 202 JobAccepted |
| GET | /body-analyses | q PageQ | Page<Analysis> 완료·실패 이력 |
| GET | /body-analyses/{analysis_id} | 없음 | Analysis |
| POST | /body-analyses/{analysis_id}/activate | 없음 | User; 본인 done 분석만 선택 |
| POST | /body-analyses/{analysis_id}/retry | 새 사진 기반이면 AnalysisPhotoInput, 글이면 text_input | 202 JobAccepted; 원본 실패 결과는 유지 |
| POST | /goal-bodies | GoalInput | 202 JobAccepted, resource_type=goal |
| GET | /goal-bodies | q PageQ | Page<Goal> revision 내림차순 |
| GET | /goal-bodies/active | 없음 | Goal 또는 data:null |
| GET | /goal-bodies/{goal_body_id} | 없음 | Goal |
| PATCH | /goal-bodies/{goal_body_id} | GoalInput 전체 새 입력 | 202 JobAccepted; 새 revision 생성, 이전 사진 재사용은 유효한 임시 파일일 때만 |
| DELETE | /goal-bodies | 없음 | 202 JobAccepted; 목표 전체 revision 및 잔여 원본 삭제 |
| POST | /body-comparisons | current_analysis_id ID,goal_body_id ID | 202 JobAccepted, resource_type=comparison |
| GET | /body-comparisons/{comparison_id} | 없음 | Comparison |
| GET | /body-comparisons/latest | 없음 | Comparison 또는 data:null, 현재 활성 입력에 대응하는 최신 결과 |

원본 `/body-analyses/reanalyze`는 신규 분석 POST와 중복되므로 제거했다. 재분석은 새 입력으로 photo/text POST, 실패 재시도는 retry를 사용한다. 원본 목표 개별 DELETE는 revision 혼동을 피하기 위해 목표 전체 삭제로 통일했다. FE는 이 변경을 이전 API와 혼용하지 않는다.

## 6. 운동·기록·교정

| Method | URL | 입력 | 결과·조건 |
| --- | --- | --- | --- |
| GET | /exercises | q target_part enum?,difficulty enum?,equipment enum?,PageQ | Page<Exercise> active만 |
| GET | /exercises/{exercise_id} | 없음 | Exercise |
| POST | /routines | comparison_id ID,week_start date? default 이번 주 월요일 | 202 JobAccepted; 입력 revision 일치 검증 |
| GET | /routines/weekly | q WeekQ | Routine 또는 data:null, 해당 주 active |
| GET | /routines/today | q date date? | TodayRoutine |
| GET | /routines/{routine_id} | 없음 | Routine; 과거 버전도 본인 조회 가능 |
| POST | /workout-logs | routine_id ID | 201 WorkoutLog; 오늘 운동 항목이 없으면 409, 기존 열린 세션 있으면 409와 current_log_id |
| GET | /workout-logs/current | 없음 | WorkoutLog 또는 data:null |
| GET | /workout-logs | q DateRangeQ,PageQ,status enum? | Page<WorkoutSummary> |
| GET | /workout-logs/stats | q DateRangeQ | WorkoutStats |
| GET | /workout-logs/{log_id} | 없음 | WorkoutLog |
| POST | /workout-logs/{log_id}/sets | SetCreateInput | 201 WorkoutSet; 열린 세션에만 허용 |
| PATCH | /workout-logs/{log_id}/sets/{set_id} | SetPatchInput | WorkoutSet |
| DELETE | /workout-logs/{log_id}/sets/{set_id} | q version int 필수 | 204; 완료 세션 수정 불가 |
| POST | /workout-logs/{log_id}/pause | version int | WorkoutLog; in_progress만 |
| POST | /workout-logs/{log_id}/resume | version int | WorkoutLog; paused만 |
| POST | /workout-logs/{log_id}/abort | version int | WorkoutLog; 미션·통계 제외 |
| POST | /workout-logs/{log_id}/complete | version int | WorkoutLog; 완료 세트 최소 1개, 완료된 세션에 재요청하면 기존 결과 |
| GET | /correction-exercises | q target_issue enum?,PageQ | Page<Correction> |
| GET | /correction-exercises/{exercise_id} | 없음 | Correction |
| GET | /body-analyses/{analysis_id}/corrections | 없음 | CorrectionPlan; unavailable은 빈 운동 목록과 reason |

세션 경로의 log_id와 set.log_item.log_id가 일치해야 한다. 서버가 started_at·ended_at·workout_date·인정 시간을 계산하며 앱이 지정할 수 없다. 원본 종료 PATCH는 명시적 상태 전이를 드러내도록 POST 동작으로 통일했다.

## 7. 식단·상품·미션·쿠폰

| Method | URL | 입력 | 결과·조건 |
| --- | --- | --- | --- |
| POST | /diet-plans | comparison_id ID,plan_date date? default 오늘 | 202 JobAccepted; 유효 nutrition profile 없으면 실패 코드 |
| GET | /diet-plans | q plan_date date? default 오늘 | DietPlan 또는 data:null, 해당 날짜 active |
| GET | /diet-plans/{plan_id} | 없음 | DietPlan; 알레르기 충돌 시 409 DIET_REVALIDATION_REQUIRED |
| GET | /partner-products | q category enum?,plan_id ID?,PageQ | Page<Product>; plan_id 제공 시 본인 식단 맥락으로 추천·필터 |
| GET | /partner-products/{product_id} | 없음 | Product; 노출 기간·계약 유효 대상만 |
| GET | /missions/current | 없음 | CurrentMission |
| GET | /user-missions/{user_mission_id} | 없음 | MissionProgress; 정의 ID와 참여 ID 분리 |
| GET | /user-coupons | q status enum(available,used,expired)?,PageQ | Page<CouponSummary> |
| GET | /user-coupons/{user_coupon_id} | 없음 | UserCoupon |
| POST | /user-coupons/{user_coupon_id}/use | confirmation bool=true | UserCoupon; self_report 처리, 만료면 409, 이미 used면 기존 결과 |

미션 배정·진행 갱신·쿠폰 지급은 서버 내부 이벤트/배치로 수행한다. 클라이언트에 ‘달성 처리’·‘보상 지급’ API를 노출하지 않는다. v1에는 식단 섭취 기록 API가 없다.

## 8. AI 코치

| Method | URL | 입력 | 결과·조건 |
| --- | --- | --- | --- |
| POST | /ai/chat | content string 1~2000 | 202 JobAccepted; 한도 예약, job 결과 type=chat_message |
| GET | /ai/chat | q PageQ | Page<ChatMessage>; 최근순, FE 표시 시 역순 가능 |
| GET | /ai/chat/{message_id} | 없음 | ChatMessage |
| GET | /ai/routine-suggestions/{suggestion_id} | 없음 | Suggestion |
| POST | /ai/routine-suggestions/{suggestion_id}/confirm | confirmed bool,base_version int | Suggestion; true 승인·false 거절, 승인 결과 applied_routine_id |
| GET | /ai/usage | 없음 | AiUsage |

수정안 생성은 chat 결과의 suggestion_id로 알려준다. 자유 텍스트를 FE가 파싱하여 운동 계획으로 적용하지 않는다. 생성·승인 모두 서버의 운동 처방 검증을 통과해야 한다. 제안 만료는 24시간, 기존 루틴이 바뀌면 409 SUGGESTION_STALE. 같은 제안을 같은 결정으로 재전송하면 기존 결과, 반대 결정은 409.

## 9. 커뮤니티·신고·차단

| Method | URL | 입력 | 결과·조건 |
| --- | --- | --- | --- |
| POST | /community-assets | multipart image file, 최대 10MiB JPG/PNG | 201 CommunityAsset, 미첨부 1시간 만료 |
| DELETE | /community-assets/{asset_id} | 없음 | 204; 본인 unattached만, 첨부 이미지는 게시글 수정에서 제거 |
| GET | /posts | q category enum?,PageQ | Page<PostSummary> |
| POST | /posts | PostInput | 201 Post |
| GET | /posts/{post_id} | 없음 | Post; 댓글은 별도 페이지 API |
| PATCH | /posts/{post_id} | Patch<PostInput> | Post; image_asset_ids 제공 시 전체 이미지 순서 교체, 본인 미첨부 또는 기존 첨부만 |
| DELETE | /posts/{post_id} | 없음 | 204; 본인 글 |
| GET | /posts/{post_id}/comments | q PageQ | Page<Comment>, 생성일·ID 오름차순 |
| POST | /posts/{post_id}/comments | content string 1~500 | 201 Comment |
| DELETE | /posts/{post_id}/comments/{comment_id} | 없음 | 204; 본인 댓글, path 관계 검증 |
| POST | /posts/{post_id}/likes | 없음 | {liked:true,like_count}; 이미 좋아요도 같은 결과 |
| DELETE | /posts/{post_id}/likes | 없음 | {liked:false,like_count}; 없으면 그대로 |
| POST | /reports | target_type enum(post,comment),target_id ID,reason enum,detail string? 최대 500 | 201 Report, 중복이면 200 기존 Report |
| GET | /reports | q PageQ | Page<Report> 본인 신고 |
| POST | /blocks/{blocked_user_id} | 없음 | {blocked:true}; 자기 차단 422 |
| DELETE | /blocks/{blocked_user_id} | 없음 | 204 |
| GET | /blocks | q PageQ | Page<Block> |

차단된 작성자의 직접 링크·댓글 조회도 목록과 동일하게 제외한다. 숨김·삭제된 게시글에는 댓글·좋아요를 추가할 수 없다. 작성자 본인에게는 관리용 상태를 보여줄 수 있지만 일반 콘텐츠 API는 숨김 대상을 404로 응답한다.

## 10. 연속 기록·알림·기기

| Method | URL | 입력 | 결과·조건 |
| --- | --- | --- | --- |
| GET | /streaks | 없음 | Streak |
| GET | /notification-settings | 없음 | NotificationSetting[] 3종 |
| PATCH | /notification-settings/{type} | enabled bool?,time time? | NotificationSetting |
| PUT | /devices/{device_id} | platform enum(android,ios),push_token string?,push_enabled bool | {device_id,platform,push_enabled}; device_id는 앱 생성 UUID |
| DELETE | /devices/{device_id} | 없음 | 204; 본인 기기 연결 해제 |

기기 권한 거부·토큰 미발급은 설정 조회 실패 사유가 아니다. 앱은 OS 권한과 서버 종류별 설정을 별도로 표시한다. 같은 토큰이 다른 사용자로 재등록되면 기존 사용자 연결을 해제한다.

## 11. 관리자

모든 API는 `/admin` 아래로 통일한다. super_admin은 전체, content_manager는 운동·영양 마스터·신고, partner_manager는 제휴·미션·쿠폰만 허용한다. 회원 조회는 super_admin만 허용한다. 관리자 UI는 이 API 범위의 별도 업무이며 실제 화면 기술 선택은 이 명세에서 강제하지 않는다.

표의 List는 Page<Resource>, Detail/Create/Patch는 Resource를 반환한다. PATCH는 해당 Input의 부분 변경이며 재검증한다. 관리자 변경에는 `reason string 1~1000`을 추가 입력하여 감사 기록에 남긴다. 수정 필드에서 reason은 리소스 값이 아닌 조치 사유다.

| Method | URL | 입력 | 결과 |
| --- | --- | --- | --- |
| GET | /admin/users | q PageQ | Page<User + account_status> |
| GET | /admin/users/{user_id} | 없음 | User + account_status |
| GET | /admin/partners | q PageQ | List<Partner> |
| GET | /admin/partners/{partner_id} | 없음 | Partner |
| POST | /admin/partners | name string,contract_start date,contract_end date,active bool,reason | 201 Partner |
| PATCH | /admin/partners/{partner_id} | 위 필드의 부분 변경,reason | Partner |
| GET | /admin/partner-products | q partner_id ID?,PageQ | List<ProductAdmin> |
| GET | /admin/partner-products/{product_id} | 없음 | ProductAdmin |
| POST | /admin/partner-products | ProductInput,reason | 201 ProductAdmin |
| PATCH | /admin/partner-products/{product_id} | Patch<ProductInput>,reason | ProductAdmin; partner_id 변경 불가 |
| GET | /admin/missions | q PageQ | List<MissionDefinition> |
| GET | /admin/missions/{mission_id} | 없음 | MissionDefinition |
| POST | /admin/missions | MissionInput,reason | 201 MissionDefinition |
| PATCH | /admin/missions/{mission_id} | Patch<MissionInput>,reason | MissionDefinition; 진행 중 참여 snapshot 불변 |
| GET | /admin/coupons | q PageQ | List<CouponDefinition> |
| GET | /admin/coupons/{coupon_id} | 없음 | CouponDefinition + available_code_count |
| POST | /admin/coupons | CouponInput,reason | 201 CouponDefinition |
| PATCH | /admin/coupons/{coupon_id} | Patch<CouponInput>,reason | CouponDefinition; 기존 발급 혜택 불변, partner_id 변경 불가 |
| POST | /admin/coupons/{coupon_id}/codes | codes string[] 1~1000개,reason | 201 {inserted_count,duplicate_count}; 코드 원문 응답·로그 금지 |
| GET | /admin/exercises | q PageQ | List<ExerciseAdmin> |
| GET | /admin/exercises/{exercise_id} | 없음 | ExerciseAdmin + prescriptions |
| POST | /admin/exercises | ExerciseInput,reason | 201 ExerciseAdmin |
| PATCH | /admin/exercises/{exercise_id} | Patch<ExerciseInput>,reason | ExerciseAdmin |
| POST | /admin/exercises/{exercise_id}/prescriptions | PrescriptionInput,reason | 201 Prescription; 새 경력별 버전 생성·기존 비활성화 |
| GET | /admin/correction-exercises | q PageQ | List<CorrectionAdmin> |
| GET | /admin/correction-exercises/{exercise_id} | 없음 | CorrectionAdmin |
| POST | /admin/correction-exercises | CorrectionInput,reason | 201 CorrectionAdmin |
| PATCH | /admin/correction-exercises/{exercise_id} | Patch<CorrectionInput>,reason | CorrectionAdmin |
| GET | /admin/reports | q status enum?,PageQ | List<Report> |
| GET | /admin/reports/{report_id} | 없음 | Report + target_preview:{type,id,moderation_status,content?} |
| POST | /admin/reports/{report_id}/resolve | action enum(restore,delete,dismiss),reason | Report; 관련 신고·대상 상태 동시 처리 |
| POST | /admin/posts/{post_id}/moderation | action enum(hide,restore,delete),reason | {target_id,moderation_status} |
| POST | /admin/comments/{comment_id}/moderation | action enum(hide,restore,delete),reason | {target_id,moderation_status} |

measurement_profiles·nutrition_profiles·foods는 초기 운영 데이터 배포 절차로 검증·등록한다. v1에서 임의 JSON을 넣어 즉시 활성화하는 일반 관리 API를 제공하지 않는다. 작성·검증·승인 책임자는 각각 AI 담당·BE 담당·팀장으로 두며 검증 근거와 버전을 저장한다. API 미제공이 임의 모델 출력 사용을 허용하는 것은 아니다.

## 12. 오류·경계 처리

| HTTP | code | 처리 |
| --- | --- | --- |
| 400 | INVALID_JSON | 요청 형식 수정 |
| 401 | AUTH_REQUIRED / TOKEN_EXPIRED / REFRESH_REVOKED | refresh 가능 시 1회, 실패하면 로그인 |
| 403 | CONSENT_REQUIRED / ADMIN_PERMISSION_REQUIRED | 동의 화면 또는 접근 불가 |
| 404 | RESOURCE_NOT_FOUND | 삭제·잘못된 링크·다른 사용자 객체를 동일 처리 |
| 409 | EMAIL_ALREADY_EXISTS / ACCOUNT_LINK_REQUIRED | 기존 로그인 수단 안내, 자동 계정 합치기 없음 |
| 409 | PROFILE_ALREADY_EXISTS / ALLERGY_ALREADY_EXISTS | 기존 데이터 조회·수정 |
| 409 | VERSION_CONFLICT / SUGGESTION_STALE | 최신 데이터 조회 후 사용자가 재검토 |
| 409 | WORKOUT_ALREADY_ACTIVE / WORKOUT_CLOSED / REST_DAY | 진행 세션 복귀 또는 현재 상태 안내 |
| 409 | INPUT_REVISION_CHANGED / COMPARISON_STALE | 최신 입력으로 비교부터 재생성 |
| 409 | IDEMPOTENCY_KEY_REUSED | 다른 요청이면 새 키 사용 |
| 409 | COUPON_EXPIRED / SUGGESTION_EXPIRED | 사용·승인 불가, 목록 갱신 |
| 409 | DIET_REVALIDATION_REQUIRED | 이전 식단 메뉴 노출 중단, 재생성 |
| 409 | RESOURCE_IN_USE | 원본이 필요한 실행 작업 종료·취소 후 변경 |
| 413 | FILE_TOO_LARGE | 10MiB 이하 재선택 |
| 415 | UNSUPPORTED_IMAGE_TYPE | JPG/PNG 안내 |
| 422 | VALIDATION_FAILED / INVALID_RESOURCE_RELATION | 필드·참조 조건 확인 |
| 422 | BODY_NOT_FULL / MULTIPLE_PEOPLE / IMAGE_BLURRY / LANDMARKS_UNAVAILABLE | 재촬영 안내, 사진 분석 job에서도 같은 코드 사용 |
| 422 | NUTRITION_PROFILE_UNSUPPORTED / ALLERGEN_DATA_UNAVAILABLE | 지원 가능한 정보·검증 데이터 확보 전 추천 미제공 |
| 429 | AI_DAILY_LIMIT / RATE_LIMITED | reset_at 또는 Retry-After 제공 |
| 503 | ANALYSIS_TIMEOUT / GENERATION_TIMEOUT / AI_UNAVAILABLE | 새 요청으로 재시도 가능, 기존 결과 유지 |
| 503 | MODEL_OUTPUT_INVALID / NO_VALID_EXERCISE / NUTRITION_PROFILE_UNAVAILABLE | 잘못된 추천 미게시, 운영 확인·대체 경로 |
| 503 | STORAGE_DELETE_FAILED | 접근 차단 유지·삭제 재시도, 완료로 표시 금지 |

job 오류에 기재된 HTTP 값은 동기 요청에서 같은 문제를 발견했을 때의 매핑이다. 이미 202로 접수된 job의 최종 실패는 GET job의 error에 표현한다. API 서버 내부 stack trace·모델 prompt·개인정보를 오류에 노출하지 않는다.

## 13. FE·BE·AI 인수 시나리오

1. AI 처리 동의까지 완료한 신규 이메일 가입의 AuthResult에서 setup_state=survey_required 확인. 프로필 저장 후 analysis_required로 전환. AI 동의 미완료 계정은 consent_required로 분기하며 사진 동의 미완료만으로 글 분석을 차단하지 않음.
2. 사진 분석 접수→job 대기→완료→Analysis 확인. 측면 미입력 시 forward_neck는 unavailable, UI는 0도로 표시하지 않음.
3. 목표 job 완료 후 목표 사진 URL 미노출·저장소 원본 삭제 확인. Goal 특징으로 비교·루틴·식단 생성.
4. 첫 세트 완료 요청 전송 후 앱 강제 종료. current와 로컬 키로 복원해 세트 중복 0, 타이머 재시작 0 확인.
5. 루틴 수정안 생성 후 프로필 변경·재추천. 이전 수정안 승인 시 409, 새 루틴에 묵시 적용 금지.
6. 두 동시 완료 요청·미션 갱신 요청으로 같은 날짜 인정 1회·쿠폰 1개 확인.
7. 알레르기 변경 후 과거 식단 접근 시 재검증 필요. 기존 운동 기록은 유지.
8. 신고자 1명의 반복 신고는 1건, 서로 다른 3명은 숨김. 관리자 restore 후 다시 일반 조회 가능.
9. 탈퇴 직후 기존 access/refresh·사진 URL 접근 차단. status_token으로 삭제 진행 확인, 파일 실패 시 완료 상태 금지.
10. AI 질문 29회 성공 후 동시 2요청에서 1개만 예약. 실패 예약은 해당 날짜에 환원.

이 문서의 테스트는 구현 완료를 주장하는 테스트 결과가 아니라 이후 구현이 충족해야 할 계약이다.
