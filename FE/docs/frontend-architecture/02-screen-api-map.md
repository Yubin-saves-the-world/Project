> 현재 API 기준은 [팀장 API 명세](../api-baseline/README.md)입니다. 이 문서의 이전 제안과 충돌하면 최신 기준을 따릅니다.

# 피그마 화면·기능·API 연결표

파일 키: pdQ0Dn4jcL4m7FC0hXAQ7x · 페이지: Page 1 / 0:1 · 확인일: 2026-10-06

최상위 프레임 14개 중 내용이 있는 프레임은 12개다. 신체정보는 2개 디자인 안이 있으며, 로그인 프레임 이름은 회원가입으로 되어 있다. 따라서 프레임 개수를 그대로 페이지 개수로 삼지 않는다. 아래 링크는 확인한 실제 노드다.

## 1. 피그마와 프론트 파일 연결

| 피그마에서 확인한 화면 | 노드 | 권장 파일 | 기능·단계 | 연결할 API/데이터 |
| --- | --- | --- | --- | --- |
| 01 회원가입 | [269:262](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=269-262) | auth/presentation/pages/signup_page.dart | F-01·MVP | POST /api/users → POST /api/auth/login → GET /api/users/me |
| 이름은 01 회원가입, 본문은 로그인 | [581:75](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=581-75) | auth/presentation/pages/login_page.dart | F-02·MVP | POST /api/auth/login, GET /api/users/me |
| 02 신체정보: 횟수 구간 선택 | [269:263](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=269-263) | profile/presentation/pages/profile_form_page.dart | F-03·MVP | POST/GET/PATCH /api/users/me/profile |
| 02 신체정보: 2·3·4·5·6+ 선택 | [581:6](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=581-6) | 위와 같은 파일, 별도 페이지 생성 없음 | F-03·MVP | 동일, 정확한 횟수 입력으로 계약 정렬 필요 |
| 03 체형분석 입력 | [269:265](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=269-265) | body_analysis/presentation/pages/analysis_entry_page.dart | F-04~06·MVP, 글 분석 F-14·2차 | POST /api/photos, 목표 API, POST /api/body-analyses/photo, GET /api/body-analyses/usage |
| 04: 빈 프레임 | [269:267](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=269-267) | 특정 구현 파일로 확정하지 않음 | 요구사항에는 진행·결과 필요 | 아래 미설계 화면 표 참조 |
| 05 홈 | [541:7](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=541-7) | home/presentation/pages/home_page.dart | F-07·09·10·MVP | GET /api/routines/weekly, GET /api/routines/today, GET /api/workout-logs. 연속일·식단·미션은 단계별 추가 |
| 06 운동 기록: 실제로는 운동 실행 화면 | [541:9](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=541-9) | workout/presentation/pages/workout_execution_page.dart | F-09·MVP | POST /api/workout-logs, 세트 POST/PATCH/DELETE, 로그 상세 GET, complete PATCH |
| 07 AI 코치 | [541:11](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=541-11) | ai_coach/presentation/pages/ai_chat_page.dart | F-19·2차 | POST/GET /api/ai/chat, 제안 confirm, GET /api/ai/usage |
| 07 AI 코치: 빈 복사본 | [570:66](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=570-66) | 별도 파일 없음 | 디자인 미완성 | 완성된 541:11을 참고 |
| 09 커뮤니티 | [570:132](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=570-132) | community/presentation/pages/post_list_page.dart | F-20·21·2차 | 게시글·댓글·좋아요, 신고·차단 API |
| 10 자세 교정 | [570:134](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=570-134) | correction/presentation/pages/correction_list_page.dart | F-17·2차 | 검증된 분석 판정, GET /api/correction-exercises 및 상세 |
| 11 맞춤 식단 | [570:136](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=570-136) | diet/presentation/pages/diet_plan_page.dart | F-18·2차 | POST/GET /api/diet-plans 및 상세, 알레르기 API. 제휴 카드는 확장 |
| 12 설정 | [570:138](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=570-138) | settings/presentation/pages/settings_page.dart | F-11·MVP | 내 정보·프로필·목표·분석·사진·로그아웃·탈퇴. 알림 설정은 확장 |

이 표의 기능 경로 앞에는 lib/features/가 붙는다. 피그마의 고정 이름·각도·칼로리·중량·시간은 디자인 예시다. 같은 값을 서버 데이터가 없는 실제 화면의 기본값으로 넣지 않는다.

## 2. 문서에 필요한데 디자인이 없는 화면

| 필요한 화면 | 권장 파일/위치 | API·필요한 상태 |
| --- | --- | --- |
| 동의 체크와 약관 보기 | auth/consent_page.dart, policy_page.dart | 약관·개인정보·사진·AI 동의, PATCH /api/users/me |
| 카메라/앨범 선택·정면/측면 미리보기 | photos/photo_input_field.dart | 시스템 선택기, 취소·권한 거절·검증·업로드 실패 |
| 목표 설명 입력·수정·분석 상태 | goal_body/goal_body_form_page.dart | 목표 POST/GET/PATCH/DELETE, pending/done/failed |
| 분석 진행 | body_analysis/analysis_progress_page.dart | pending·60초 이후 처리 중·복귀 조회 |
| 분석 결과 | body_analysis/analysis_result_page.dart | 측정값·평가 불가·AI 의견·루틴 생성 |
| 분석 이력 | body_analysis/analysis_history_page.dart | GET /api/body-analyses, 상태별 목록 |
| 종목 선택·상세 | exercises/exercise_catalog_page.dart, exercise_detail_page.dart | GET /api/exercises 및 상세, 필터·빈 목록 |
| 루틴 전체 종목 상세 | routines/routine_detail_page.dart | GET /api/routines/{routine_id} |
| 날짜별 운동 이력·상세 | workout/workout_history_page.dart, workout_detail_page.dart | GET /api/workout-logs 및 상세, 완료 기록 수정·삭제 |
| 사진 데이터 관리 | photos/photo_management_page.dart | 목록·개별/전체 삭제·URL 만료 |
| 탈퇴 확인·접수 결과 | settings/account_deletion_page.dart | 원문204 또는 v1.2 제안202, 응답 유실 |
| 비밀번호 재설정·게시글 상세/작성·신고/차단·알레르기 | 각 기능의 후속 페이지 | 2차 API에 맞춰 별도 설계 |
| 미션·할인권·알림 설정·제휴 상품 상세 | rewards/notifications/marketplace | 확장 API에 맞춰 별도 설계 |

여기서 경로는 기능 폴더와 파일명만 줄여 쓴 것이다. 실제 페이지 경로는 모두 presentation/pages/ 아래다. 사진 입력·신고·동의 설명은 바텀시트/다이얼로그로 충분하면 전체 페이지를 만들지 않는다.

## 3. 디자인과 문서의 충돌: 프론트 적용 기준

| 발견한 차이 | 프론트 구조와 기본 처리 | 팀 확인 사항 |
| --- | --- | --- |
| 가입·로그인에 AUTHENTICATION NUMBER가 있으나 메일 인증 API 없음 | 인증번호 모델·타이머·API를 만들지 않고 MVP 화면에서 제외 | 이메일 인증을 추가할 경우 BE 계약 먼저 필요 |
| 로그인 복사본에 닉네임·가입 안내가 남음 | 로그인 폼은 email/password만, 가입 폼과 분리 | 피그마 프레임 이름·문구 정리 |
| 카카오 버튼이 있으나 팀장 문서는 Google만 2차 | 카카오 파일 없음, Google 버튼은 2차 flag | Google SDK 입력이 서버의 id_token 등 실제 계약과 일치해야 함 |
| 횟수가 구간 또는 6+인데 API는 1~7 정수 | 정확한 1~7 선택 UI 제안. 범위를 임의의 정수로 변환하지 않음 | 두 신체정보 안 중 하나 선택 및 선택지 수정 |
| 성별은 남·여뿐이나 API는 none 허용 | 선택 안 함/미응답 추가 | 프로필 정책 확인 |
| 가입→신체정보→분석 3단계가 모두 필수처럼 보임 | 프로필 저장으로 onboarding 완료. 분석에는 나중에 하기 제공 | 분석 없이 자유 운동·기록 진입 확인 |
| 가입하면 자동 동의라는 문구 | 별도 동의 체크 UI. 사진·AI 선택 동의는 v1.2 제안 여부에 맞춤 | 필수 동의 4종 원문과 2종 제안 중 계약 확정 |
| 홈에 식단·교정·미션·연속일·알림 종이 함께 있음 | 단계별 feature flag로 화면과 API 호출을 함께 숨김 | 준비되지 않은 값을 가짜로 표시하지 않음 |
| 분석 결과 프레임이 비어 있음 | 수치·평가 불가·AI 설명 카드 재사용 방식으로 별도 설계 | 로딩·실패·측면 없음·목표 없음 디자인 필요 |
| 운동 실행에 타이머 일시정지 버튼 | MVP는 서버 시작 시각 기반 경과 시간. 전체 운동 일시정지는 계약 확정 전 제외 | 앱 활성 시간만 재려면 로컬 pause 누적값·duration 제출 규칙 필요 |
| 세트 완료 버튼만 있고 종목 종료 동작이 없음 | 세트 저장과 종목 종료를 다른 행동으로 구성 | 완료 후 다음 종목 진입·전체 루틴 완료 화면 필요 |
| 운동 실행의 오늘 총 볼륨 범위가 모호함 | log 단위와 날짜 전체 합계를 다른 모델 값으로 표시 | 선택한 단위에 맞춘 라벨 확정 |
| AI 카드에 이미 스트레칭을 넣었다는 문구 | 서버에 승인된 변경 전에는 제안으로 표시 | 제안·승인·적용·만료 상태 디자인 필요 |
| AI·식단 설명이 사진에서 등 두께를 측정한 것처럼 표현됨 | 예시 문구를 실제 검증된 측정과 AI 의견에 맞게 교체 | 실제 모델 출력·설명 계약 확인 |
| 교정 화면 시작 버튼이 있으나 별도 교정 운동 기록 API 없음 | 가이드 상세·앱 내 안내 타이머까지만, 일반 운동 로그에 임의 연결 금지 | 교정 기록이 필요하면 exercise 매핑/API 확정 |
| 설정에 목표 체형 사진 변경이 있음 | 목표 요약·설명을 보여주고 새 사진으로 교체. 처리 후 원본 상시 표시 기대 금지 | 목표 원본 삭제 정책을 디자인에 반영 |

## 4. 공통 UI 추출 기준

확인한 홈·운동·가입·신체정보·분석 입력·설정 프레임의 배경은 #FAFAF8, 주 CTA는 #7BAF1E다. CTA 모서리는 14이고 주요 화면 좌우 여백은 24다. 한국어 텍스트에는 Noto Sans KR, 영문·일부 수치에는 Inter가 사용됐다. 전체 화면은 주로 393×852이며 설정/식단은 더 길다.

이 값은 확인한 노드의 속성에서 읽은 값이며 파일 전체의 완성된 디자인 토큰 체계라고 주장하지 않는다. Flutter에서는 다음처럼 통합한다.

| 반복 요소 | 공통 위치 | 상태/유의점 |
| --- | --- | --- |
| 초록 CTA·보조 버튼 | ui/core/widgets/primary_button.dart 등 | 처리 중·disabled·중복 탭 방지 |
| 입력 필드·칩 선택 | ui/core/widgets/ | 오류·미선택·키보드 입력·범위 검사 |
| 카드·구분선·여백·글꼴 | ui/core/theme/, section_card.dart | 실제 텍스트 길이와 접근성 글꼴 확대 |
| 상단 뒤로·안전 영역 | app_scaffold.dart | 기기 status bar·키보드와 중복 여백 금지 |
| 하단 탭 | app/shell/ | 화면마다 복사하지 않고 탭 상태 유지 |
| 요일 띠 | home/widgets/week_strip.dart | 생성·휴식·완료·미생성 표시 |
| 분석 배지·수치 | body_analysis/widgets/ | null을 0/정상으로 표시하지 않음 |
| 세트 행·휴식 타이머 | workout/widgets/ | 서버 저장 완료와 입력 초안 구분 |
| 대화 말풍선·제안 | ai_coach/widgets/ | 역할·요청 대기·승인 가능 여부 |

393×852를 앱 전체 고정 크기로 설정하지 않는다. SafeArea·스크롤·폭 제약으로 작은 기기와 큰 글꼴을 수용한다. 피그마 자체를 단일 이미지로 내보내 화면으로 사용하지 않는다.

## 5. 라우트 제안

이 경로는 앱 내부 경로이며 서버 API 경로가 아니다. ID가 필요한 화면에는 ID만 전달하고 데이터는 Repository로 조회한다.

| 내부 경로 | 화면 | 탭 포함 |
| --- | --- | --- |
| /login, /signup, /consents, /policies/:type | 인증·동의 | 없음 |
| /profile/setup, /profile/edit | 같은 프로필 폼의 최초/편집 모드 | 없음 |
| /home | 홈 | 홈 탭 |
| /analysis | 분석 입력 | 분석 탭 |
| /analysis/history | 분석 이력 | 분석 탭 |
| /analysis/:analysisId | 진행/결과 상태를 조회하여 표시 | 분석 탭 |
| /goals/edit | 목표 설정 | 없음 |
| /exercises, /exercises/:exerciseId | 종목 선택·상세 | 없음 |
| /routines/:routineId | 루틴 상세 | 없음 |
| /workouts | 운동 이력 | 기록 탭 |
| /workouts/:logId | 기록 상세 | 기록 탭 |
| /workouts/:logId/run | 운동 실행, 복원 가능 | 없음 |
| /settings, /settings/photos, /settings/account-deletion | 설정·사진·탈퇴 | 없음 |
| /coach, /community, /community/:postId, /community/new | AI·게시판 | 2차 탭·상세 |
| /diet, /diet/allergies, /correction, /correction/:exerciseId | 식단·교정 | 없음 |
| /missions, /coupons, /coupons/:couponId, /products/:productId, /settings/notifications | 확장 | 없음 |

등록 시 /analysis/history, /community/new, /workouts/:logId/run 같은 경로를 단순 ID 경로와 구분한다. auth redirect는 로그인·동의·설문에만 적용하고 운동 이어하기를 반복 강제하지 않는다. 최초 홈에서 이어하기 배너로 안내한다. 설정 화면 접근 버튼은 홈 헤더에 추가하는 제안이다. 피그마의 알림 종을 설정 버튼으로 조용히 바꾸지 않는다.
