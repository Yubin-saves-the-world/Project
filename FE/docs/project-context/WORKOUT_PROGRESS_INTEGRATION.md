# 운동 진행 연동 (T9)

2026-10-27 · 작업 대상 `/Users/yubin/StudioProjects/Project/FE`.

이전 T8 홈 연동은 `94dedaa` (`feat: 홈 서버 데이터 및 추천 일정 선택 연동`)로 커밋하고 origin/main에 Push했다. 아래 T9 변경은 다음 작업으로 구현했으며 아직 커밋·Push하지 않았다.

## 진입과 사용

- 홈 운동 기록 카드의 **자유 운동 시작** → 종목 목록 → 상세의 **이 운동 시작**.
- 오늘의 예정 추천 루틴 상세 → 미완료 종목의 **이 종목 시작 · 이어하기**. `routine_id`와 목표 세트·횟수·무게·휴식을 전달한다. 지난/미래 날짜·건너뛴/완료 상태의 루틴을 오늘 운동으로 잘못 시작하지 않도록 제한했다.
- 홈 운동 기록 카드의 **이어하기 · 종목명** → 기존 `log_id`를 조회한다. 재개용 POST로 새 기록을 만들지 않는다.
- 뒤로가기는 운동을 삭제하거나 종료하지 않는다. 복귀 후 홈은 서버 기록을 다시 조회한다. 앱 시작 시에도 기존 홈의 진행 기록 조회를 통해 이어하기를 제공한다.

화면에는 종목·서버 시작 시각 기준 경과 시간·목표·세트·휴식 타이머를 표시한다. 무게/횟수를 입력해 완료 세트를 추가하고, 완료 해제·수정·확인 후 삭제할 수 있다. 종료 버튼은 안전 영역 안에 두고 본문만 스크롤한다. 오류 문구로 버튼이 본문 아래로 밀리지 않는다. 기존 흰색/파란색·폰트·관리 화면 양식을 사용했고 기존 홈 아이콘이나 Figma 파일은 변경하지 않았다.

## 계약과 복원

- API: POST `/workout-logs`, GET `/workout-logs/{id}`, POST `/sets`, PATCH/DELETE `/sets/{set_id}`, PATCH `/complete`, DELETE `/workout-logs/{id}`. 공통 `ApiClient`와 인증/온보딩 오류 처리를 사용한다.
- 시작은 201 신규/200 기존 기록 모두 실제 상세를 조회한다. 서버가 다른 루틴에 연결된 진행 기록을 반환하면 기존 연결을 유지하고 이를 안내한다.
- 완료 버튼을 누를 때 UUID v4인 `client_set_id`와 본문을 **계정·로그별 로컬 저장소에 먼저 저장**한다. 저장 실패 시 서버로 보내지 않는다. 타임아웃/앱 재실행 후에도 같은 ID와 본문으로 재전송한다. 이미 서버에서 같은 ID가 확인되면 미확인 상태를 해제한다.
- 전송 결과가 불확실하면 다른 변경을 막고 먼저 서버 기록을 다시 확인한다. 서버에 없는 미전송 세트는 같은 본문으로 재시도한다. 다른 세트와 번호가 충돌하면 사용자 확인 후 그 미전송 입력만 취소하고 서버 세트는 보존한다.
- 세트 수정은 최신 `version`을 전달한다. 충돌 후 자동 덮어쓰기/자동 재전송 없이 재조회하고 사용자가 새 값을 확인해 수정한다.
- 입력 범위: 세트 번호 1~20, 무게 0~500kg, 횟수 1~100, 실제 휴식 0~3600초. 세트 삭제 후 나머지 번호를 재정렬하지 않는다. 로컬에 다음 번호도 저장해 마지막 세트 삭제 후 번호를 되돌리지 않는다.
- 경과 시간은 `현재 시각 − 서버 started_at`이다. 휴식은 앱에서 시작/정지 시각·목표를 저장하고 시각 차이로 복원한다. 세트 전송의 `rest_sec`는 직전 세트 후 실제 쉰 시간이며 추천 휴식 목표값을 그대로 기록하지 않는다.
- 첫 세트 전에도 휴식 목표를 저장한다. 새 기기처럼 복원 정보가 없으면 실제 연결된 서버 루틴에서 해당 종목의 목표·휴식을 조회한다. 휴식 타이머는 기기 로컬 기능이므로 다른 기기로 남은 휴식 초까지 동기화하지 않는다.
- 6시간 경과·aborted·completed·알 수 없는 상태는 변경을 막고 돌아가기를 제공한다. 앱 복귀 시 서버를 재조회한다. 임의로 서버 상태를 완료 처리하지 않는다.

## 종료 범위

T9 운동 흐름을 사용할 수 있도록 기본 종료/취소도 연결했다. 완료 세트가 없는 종료와 명시적 취소는 확인 후 해당 서버 로그를 삭제한다. 완료 세트가 있으면 서버 종료 API 결과의 세트 수/볼륨을 알리고 돌아간다. 서버가 WORKOUT_EMPTY를 반환해도 빈 로그를 삭제한다.

**T10 전용 종료 요약 화면·메모·다음 종목 이동·오늘 루틴 완료 화면은 아직 남아 있다.** T11의 지난 운동 기록 상세/편집/삭제도 이번 범위에 포함하지 않았다.

## 기존 기능 보존

기존 로그인·가입·온보딩·목표·분석·추천 조회·수동 주간 일정과 기기 저장 기록/인덱스/저장 형식은 유지한다. 예전 기기 운동 미리보기를 서버 종목 ID로 임의 변환하지 않았다. 실제 서버 운동 기록은 위 자유 운동/추천 루틴 진입을 사용한다. 서버 모드에서만 T9 의존성을 연결하며 로컬 미리보기에 가짜 서버 저장 성공을 추가하지 않았다. BE 코드와 패키지 의존성은 변경하지 않았다.

## 변경 파일

새 앱 코드:

- `lib/features/workout/data/workout_repository.dart`: 서버 모델과 API.
- `lib/features/workout/data/workout_draft_store.dart`: 계정·로그별 미확인 세트/타이머 복원.
- `lib/features/workout/presentation/workout_dependencies.dart`: 공유 API·저장소 조합.
- `lib/features/workout/presentation/workout_view_model.dart`: 시작·기록·충돌·복원·종료.
- `lib/features/workout/presentation/pages/workout_page.dart`: 운동 진행과 세트 수정 화면.

기존 연결 수정:

- `lib/app/onboarding/onboarding_flow.dart`, `lib/app/shell/main_shell.dart`.
- `lib/features/body_analysis/presentation/analysis_dependencies.dart`, `pages/analysis_run_page.dart`.
- `lib/features/exercises/presentation/pages/exercise_list_page.dart`, `exercise_detail_page.dart`.
- `lib/features/routines/presentation/pages/routine_week_page.dart`, `routine_detail_page.dart`.
- `lib/features/home/presentation/home_server_dependencies.dart`, `widgets/server_home_cards.dart`.

검증/문서:

- `test/fakes/fake_workout_repository.dart`.
- `test/features/workout/workout_repository_test.dart`, `workout_view_model_test.dart`, `workout_page_test.dart`, `workout_navigation_test.dart`.
- `docs/project-context/previews/workout-{start,rest}-{1.0,1.3}.png`.
- 현재 보고서, `docs/project-context/README.md`, `lib/features/workout/README.md`.

## 검증

Flutter 3.41.6 / Dart 3.11.4, 2026-10-27 실행.

- 최종 `flutter analyze --no-pub`: 문제 없음.
- 첫 세트 전 복원 보완 후 전체 회귀 테스트 **246개 통과, 실서버 2개 환경 미지정으로 미실행**. 기존 골든은 변경하지 않았다.
- 이후 추가한 다른 기기 루틴 목표 복원 항목을 포함해 운동 상태 테스트 **13개 통과**. 전체 회귀 246개에는 이 마지막 추가 항목 1개가 포함되지 않는다. 신규 T9 테스트는 총 21개(API 2·상태 13·화면 3·진입 3)다.
- 393×852 및 320×640/130% 글꼴의 시작/휴식 화면을 이미지로 확인했고, 저장 실패 시 종료 버튼 위치와 기존 화면 왕복을 검증했다.

실제 서버/실기기에서 운동·백그라운드·앱 강제 종료/재시작을 검증한 결과는 아니다. 네트워크 손실과 앱 상태 재생성은 가짜 서버/저장소 및 위젯 테스트로 검증했다. 실제 서버가 연결돼 있어야 이 기능을 사용할 수 있다. 다음 작업은 T10 운동 종료 요약이다.
