> 현재 API 기준은 [팀장 API 명세](../api-baseline/README.md)입니다. 이 문서의 이전 제안과 충돌하면 최신 기준을 따릅니다.

# 권장 폴더 구조와 파일 역할

아래 Dart 파일은 구현 계획이다. 지금 빈 파일을 전부 생성하지 않고 MVP의 첫 화면부터 필요한 파일을 만든다. 파일명은 snake_case, 화면은 *_page.dart, 상태/행동은 *_view_model.dart, 화면 값은 *_state.dart로 통일한다.

## 1. 앱·공통 기반

```text
lib/
├── main.dart                       # bootstrap 호출
├── app/
│   ├── bootstrap.dart              # 설정·저장소·의존성 준비
│   ├── vitality_app.dart           # 앱 Theme·Router 연결
│   ├── app_providers.dart          # 공통 인스턴스 주입, real/fake 저장소 선택
│   ├── app_lifecycle_observer.dart # 복귀 시 운동·분석 재조회
│   ├── config/
│   │   ├── app_config.dart         # API 주소·환경·서버 계약 설정
│   │   └── feature_flags.dart      # MVP/2차/확장 화면·호출 활성화
│   ├── router/
│   │   ├── app_router.dart         # 전체 경로 구성
│   │   ├── route_paths.dart        # 앱 경로 상수(API URL과 별개)
│   │   └── auth_redirect.dart      # 로그인·필수 동의·설문 진입 처리
│   └── shell/
│       ├── main_shell.dart         # 탭별 탐색 상태 유지
│       └── app_bottom_nav.dart     # 홈·분석·기록 / 추후 AI·커뮤니티
├── core/
│   ├── network/
│   │   ├── api_client.dart         # Dio 기본 설정·요청 취소
│   │   ├── api_paths.dart          # /api 엔드포인트 경로
│   │   ├── auth_interceptor.dart   # Bearer 토큰·401 통보
│   │   └── api_exception.dart      # status·code·message 파싱
│   ├── storage/
│   │   ├── token_store.dart        # 토큰 저장/제거 인터페이스
│   │   ├── secure_token_store.dart # 보안 저장소 구현
│   │   └── local_database.dart     # 운동 복원·미전송 작업 영속 저장
│   ├── time/
│   │   ├── clock.dart              # 테스트 가능한 현재 시간
│   │   └── kst_date.dart           # 요청 날짜 계산과 KST 변환
│   ├── media/
│   │   ├── image_picker_service.dart   # 카메라/앨범 선택·권한·취소
│   │   └── image_preprocessor.dart     # 리사이즈·회전·형식·용량 검사
│   └── validation/
│       └── input_validators.dart   # 형식 검사, 정책 범위는 기능별 소유
├── ui/core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_spacing.dart
│   │   └── app_radii.dart
│   └── widgets/
│       ├── app_scaffold.dart       # SafeArea·공통 화면 여백
│       ├── primary_button.dart     # 기본/비활성/처리 중
│       ├── secondary_button.dart
│       ├── app_text_field.dart     # 라벨·오류·비밀번호 가림
│       ├── choice_chip_group.dart
│       ├── section_card.dart
│       ├── loading_view.dart
│       ├── empty_view.dart
│       ├── error_view.dart
│       └── confirm_dialog.dart
└── features/
```

app_config에는 공개 API 주소와 환경값만 둔다. DB 비밀번호·AI 키·S3 비밀 키는 프론트 설정에 넣지 않는다. MediaPipe/Qwen 호출은 서버 API를 통해 처리한다.

ui/core에는 실제로 여러 기능에서 공유하는 UI만 둔다. 분석 판정 카드·세트 행·식단 끼니 카드를 공통 폴더에 모으지 않는다. core 역시 업무 모델의 모음이 아니다. User는 auth, Routine은 routines, Exercise는 exercises, WorkoutLog는 workout에서 소유한다.

## 2. 기능 폴더의 기본 패턴

```text
features/routines/
├── routines_providers.dart
├── data/
│   ├── models/
│   │   ├── routine.dart
│   │   ├── routine_item.dart
│   │   └── routine_day.dart
│   ├── routines_api.dart
│   ├── routines_repository.dart
│   └── api_routines_repository.dart
└── presentation/
    ├── pages/
    │   └── routine_detail_page.dart
    ├── view_models/
    │   ├── routine_detail_view_model.dart
    │   └── routine_detail_state.dart
    └── widgets/
        ├── routine_exercise_tile.dart
        └── routine_progress.dart
```

| 파일 | 책임 |
| --- | --- |
| *_api.dart | HTTP 경로·query·body·JSON 수신. BuildContext와 화면 이동 없음 |
| models/*.dart | 불변 모델·JSON 필드 매핑·nullable·enum unknown 처리 |
| *_repository.dart | 화면이 사용할 데이터 접근 계약. 백엔드/목 구현 교환 가능 |
| api_*_repository.dart | API 모델 변환·도메인별 캐시·조회/변경 일관성 |
| *_providers.dart | 해당 기능의 저장소·상태를 주입하는 공개 진입점 |
| *_view_model.dart | 사용자 행동·요청 처리·상태 전환·새로고침 |
| *_state.dart | 데이터·조회 상태·저장 중 여부·오류 등 화면 상태 |
| pages/*.dart | 레이아웃과 ViewModel 행동 연결 |
| widgets/*.dart | 해당 기능 전용의 작은 UI |

단순 조회 상태는 AsyncValue<Model>로 충분하면 별도 state 파일을 만들지 않는다. 제출 상태·입력 초안·서버 데이터가 함께 있는 분석/운동 화면은 별도 state를 둔다. 모든 모델을 DTO/domain/entity로 3번 복제하지 않는다. API 모양과 화면 의미가 달라지는 부분만 adapter/mapper를 추가한다.

## 3. MVP 기능별 파일

아래 표는 각 폴더에서 우선 만들 핵심 파일이다. 데이터가 있는 기능은 위 기본 패턴으로 API·Repository·Provider를 둔다. 표의 페이지 파일은 presentation/pages/, VM·State는 presentation/view_models/, 모델은 data/models/ 아래에 놓는다.

| 기능 | 모델·입력 | 페이지 | ViewModel·특수 파일 | 전용 위젯 |
| --- | --- | --- | --- | --- |
| auth | user.dart, auth_tokens.dart, consent_settings.dart, signup_request.dart | login_page.dart, signup_page.dart, consent_page.dart, policy_page.dart | session_view_model.dart, session_state.dart, login_view_model.dart, signup_view_model.dart, consent_view_model.dart | consent_checklist.dart, google_sign_in_button.dart(2차) |
| profile | body_profile.dart, profile_input.dart | profile_form_page.dart | profile_form_view_model.dart, profile_form_state.dart, profile_validation.dart | body_metric_input.dart, goal_type_selector.dart, frequency_selector.dart, experience_selector.dart |
| photos | body_photo.dart, photo_upload_request.dart | photo_management_page.dart | photo_upload_view_model.dart, photo_management_view_model.dart | photo_input_field.dart, shooting_guide.dart, photo_thumbnail.dart |
| body_analysis | body_analysis.dart, body_measures.dart, body_judgement.dart, goal_comparison.dart, analysis_usage.dart | analysis_entry_page.dart, analysis_progress_page.dart, analysis_result_page.dart, analysis_history_page.dart | analysis_input_view_model.dart, analysis_input_state.dart, analysis_progress_view_model.dart, analysis_result_view_model.dart, analysis_history_view_model.dart, analysis_polling_coordinator.dart | analysis_method_card.dart, measurement_card.dart, judgement_badge.dart, goal_comparison_card.dart |
| goal_body | goal_body.dart, goal_body_input.dart | goal_body_form_page.dart | goal_body_view_model.dart, goal_body_state.dart | goal_summary_card.dart |
| exercises | exercise.dart, exercise_filter.dart | exercise_catalog_page.dart, exercise_detail_page.dart | exercise_catalog_view_model.dart, exercise_detail_view_model.dart | exercise_filter_bar.dart, exercise_tile.dart |
| routines | routine.dart, routine_item.dart, routine_day.dart | routine_detail_page.dart | routine_generation_view_model.dart, routine_detail_view_model.dart | routine_exercise_tile.dart, routine_progress.dart |
| workout | workout_log.dart, workout_set.dart, workout_query.dart | workout_execution_page.dart, workout_history_page.dart, workout_detail_page.dart | workout_execution_view_model.dart, workout_execution_state.dart, workout_history_view_model.dart, workout_detail_view_model.dart, rest_timer_view_model.dart | set_input_row.dart, elapsed_timer.dart, rest_timer_card.dart, volume_summary.dart, workout_calendar.dart |
| home | home_state.dart(화면 상태) | home_page.dart | home_view_model.dart | home_header.dart, week_strip.dart, today_routine_card.dart, quick_action_card.dart |
| settings | settings_state.dart(화면 상태) | settings_page.dart, account_deletion_page.dart | settings_view_model.dart, account_deletion_view_model.dart | settings_section.dart, settings_tile.dart |

home은 routines·workout·auth/profile의 Repository를 조합한다. GET /api/home이나 home_api.dart를 새로 만들지 않는다. settings는 각 기능의 공개 Repository·세션을 사용하는 진입 화면이며 프로필·목표·사진 모델을 복제하지 않는다. 계정 삭제·동의 PATCH의 API 소유자는 auth에 통일한다.

사진 입력 위젯은 photos의 공개 UI로 body_analysis와 goal_body에서 사용한다. 프로필 최초 입력과 설정에서의 편집은 profile_form_page의 mode=create/edit으로 구분한다. 같은 프로필 화면을 복제하지 않는다.

### workout에 필요한 추가 구조

```text
features/workout/
├── workout_providers.dart
├── data/
│   ├── models/                     # WorkoutLog/WorkoutSet 등
│   ├── workout_api.dart
│   ├── workout_repository.dart
│   ├── api_workout_repository.dart
│   └── local/
│       ├── workout_draft.dart      # logId·입력 값·타이머 만료 시각
│       ├── pending_set_operation.dart # UUID·body·동기화 상태
│       └── workout_local_store.dart   # 저장·복원·동기화 완료 처리
└── presentation/
    ├── pages/                      # 실행·이력·상세
    ├── view_models/                # 조작과 타이머 상태
    ├── coordinators/
    │   └── workout_sync_coordinator.dart # 세트 재전송·순서·충돌 처리
    ├── services/
    │   └── rest_timer_alert_service.dart # 종료 알림 예약·취소
    └── widgets/                    # 세트 행·타이머·달력
```

WorkoutLog는 종목 하나의 기록이다. 하루 전체를 뜻하는 별도 서버 모델 WorkoutSession을 만들지 않는다. 루틴 4종목을 화면에서 연속 실행할 수 있지만 각 종목에는 별도 log_id가 있다.

## 4. 2차·확장 단계에 추가할 파일

다음 단계에서 같은 data/presentation 패턴을 적용한다. auth와 workout은 기존 폴더에 파일을 추가한다.

| 단계·폴더 | 주요 화면 파일 | 주요 상태/데이터 |
| --- | --- | --- |
| 2차·auth | password_reset_request_page.dart, password_reset_page.dart | reset_request_view_model.dart, password_reset_view_model.dart, google_sign_in_service.dart |
| 2차·body_analysis | text_analysis_page.dart | text_analysis_input.dart, text_analysis_view_model.dart |
| 2차·workout | workout_stats_page.dart | workout_stats.dart, streak.dart, workout_stats_view_model.dart |
| 2차·routines | 기존 상세에 건너뛰기 추가 | 기존 Repository의 skip 및 기존 VM 상태 |
| 2차·ai_coach | ai_chat_page.dart | chat_message.dart, routine_suggestion.dart, ai_usage.dart, ai_chat_view_model.dart, suggestion_card.dart |
| 2차·diet | diet_plan_page.dart, allergy_settings_page.dart | diet_plan.dart, diet_meal.dart, allergy.dart, diet_plan_view_model.dart, allergy_view_model.dart, meal_card.dart |
| 2차·correction | correction_list_page.dart, correction_detail_page.dart | correction_exercise.dart, correction_view_model.dart, issue_section.dart |
| 2차·community | post_list_page.dart, post_detail_page.dart, post_form_page.dart, blocked_users_page.dart, report_history_page.dart | post.dart, comment.dart, report.dart, block.dart, 게시글/댓글 VM, report_dialog.dart |
| 확장·marketplace | partner_product_page.dart | partner_product.dart, marketplace_view_model.dart, partner_product_card.dart |
| 확장·rewards | mission_page.dart, coupon_list_page.dart, coupon_detail_page.dart | mission.dart, mission_progress.dart, user_coupon.dart, rewards_view_model.dart |
| 확장·notifications | notification_settings_page.dart | notification_setting.dart, device_token.dart, notification_settings_view_model.dart, push_notification_service.dart |

community 안에서도 posts_api/repository와 moderation_api/repository를 나누면 댓글·차단 처리까지 거대한 한 파일이 되는 것을 피할 수 있다. rewards는 사용자 앱의 미션·할인권을 다루며 관리자 등록 기능은 포함하지 않는다.

## 5. 리소스·목 데이터·테스트

```text
assets/
├── icons/                 # 허가된 SVG 등
├── images/                # 실제 정적 리소스만
└── fonts/                 # Noto Sans KR/Inter 사용 시 파일·라이선스
dev/
└── fixtures/              # 명세에 맞춘 가짜 API JSON; 배포 자산 아님
test/
├── fakes/                 # Repository 대체 구현
├── app/                   # 라우팅·세션 분기
└── features/
    ├── body_analysis/     # null·실패·대기 상태
    └── workout/           # 재전송·버전 충돌·복원
integration_test/
└── mvp_flow_test.dart      # 가입→분석→루틴→운동→기록
docs/
└── frontend-architecture/
```

fixtures의 숫자는 실제 데이터와 혼용하지 않는다. 초기 개발에서는 가짜 Repository를 Provider override로 주입하고 화면을 완성한다. 실제 연결에도 같은 Repository 계약을 사용한다. 테스트는 복원·중복 저장·nullable·인증 이동 같은 중요한 동작을 우선한다.
