# 홈 서버 연동 (T8) — 2026-10-26

먼저 사용자 요청대로 T7을 `8d84bb7 feat: 추천 루틴 주간 조회 및 상세 관리 구현`으로 커밋하고 GitHub main에 Push했다. 이 커밋에는 실행 과정에서 생성된 url_launcher iOS Pod 잠금 파일도 포함했다. 이후 아래 T8을 실제 프로젝트에 구현했으며 **T8 자체는 아직 커밋·Push하지 않았다.**

## 서버 조회와 홈 표시

- 서버 모드의 홈에 GET /routines/today와 월요일 기준 주간 추천을 연결했다. 생성 루틴의 7일 범위가 다음 주에 걸리면 다음 주도 조회한다. 추천이 없음을 서버에서 확인한 신규 계정은 분석 화면으로 안내한다. 서버 오류를 추천 없음으로 처리하지 않는다.
- 선택한 날짜의 추천 제목·시간·종목·처방·완료 수를 기존 파란 테두리 카드에 표시하고 T7 상세로 연결한다. 직접 만든 일정이 기본이며 두 종목 목록을 자동으로 합치지 않는다.
- GET /workout-logs의 기간 전체 summary로 기록 수·세트·볼륨·완료 날짜를 표시한다. 완료 기록은 status=completed로 조회하고, in_progress는 별도로 조회해 해당 날짜의 완료된 세트/볼륨만 더한다. 진행 조회 범위는 전날~오늘이므로 자정을 넘긴 운동도 확인한다.
- 주간 완료 날짜를 요일 표시와 기존 주간 진행에 반영한다. 연속 운동일은 최대 92일 조회 범위의 실제 workout_dates에서 계산하며 범위를 넘겨 이어질 가능성은 + 표기로 제한을 나타낸다. 조회 중/오류를 가짜 0일·0개 기록으로 표시하지 않는다.
- 기존 기록 ‘보기’ 달력에서 선택한 날짜의 서버 완료 기록을 페이지로 모두 조회할 수 있다. 과거 기기 내 기록은 별도 구역에 유지한다. 서버 ID와 로컬 운동 배열 번호를 섞거나 중복 합산하지 않는다.
- 진행 중인 서버 운동의 이름·완료 세트/볼륨은 읽기 전용으로 확인한다. 실제 서버 운동 이어하기·시작·세트·타이머는 T9에서 연결한다. 기존 기기 내 운동 시작/완료는 보존하고 기기에 저장되는 기록임을 표시한다.
- 홈 복귀, 마이페이지 복귀, 앱 재개, 날짜 변경, 새로고침에서 서버 값을 갱신한다. 선택 날짜 요청의 늦은 응답은 무시한다. API 인증과 세션 만료는 기존 공통 ApiClient를 사용한다.

## 직접 일정과 추천 선택 정책

- 계정별 신규 키 `movid.home.recommendation-choice.v1.<account>`에 날짜→추천 ID 선택을 저장한다. 기존 주간 반복/날짜 일정과 운동 기록의 저장 형식은 바꾸지 않는다.
- 직접 만든 운동/휴식일과 planned 추천이 겹치면 기본은 ‘내 운동 유지’이며, 오늘/미래 추천만 skipped로 동기화한다. 이미 done이거나 진행 중인 운동이 있는 날은 자동 변경하지 않는다. 선택 정보를 읽지 못했을 때 기존 선택을 추정해 서버 상태를 바꾸지 않는다.
- ‘추천 루틴으로 교체’는 확인 창을 거치고 선택한 날짜에만 유효한 추천 ID를 적용한다. 적용 직전 상세와 진행 중 운동을 다시 확인한다. 건너뛴 추천이면 planned로 복원한 뒤 선택을 저장한다. 다른 날짜·반복 원본·완료 기록은 보존한다.
- 기존 수동 일정 데이터 자체를 물리적으로 지우지 않는다. 날짜별 추천 선택이 해당 날짜의 표시/실행 계획을 덮어쓰는 방식이므로 이전 일정과 완료 기록을 잃지 않는다. 직접 일정 편집을 저장하면 그 날짜의 추천 선택을 해제하고 새 수동 일정을 우선한다. 해제 저장 실패는 알리고 재시도 시 이전 추천 선택을 다시 적용하지 않도록 보류한 해제를 먼저 반영한다.
- 홈의 ‘운동일로 변경’은 오늘/미래에 복원 가능한 추천이 있으면 planned 복원과 날짜 선택으로 이어진다. 과거·추천 없음·복원 실패는 직접 일정 편집으로 진행한다. 사용자가 일정 편집에서 직접 종목을 골라 저장하는 경로는 명시적인 수동 선택으로 취급한다.
- 서버나 선택 저장에 실패하면 직접 만든 일정/기록을 지우지 않고 오류/재시도를 제공한다. 휴식일/추천 선택의 기기 간 동기화가 구현된 것은 아니다. 수동 일정과 날짜 선택은 이 기기에 보존된다.

## 변경 파일

신규:

- `lib/features/home/data/models/server_home_data.dart`
- `lib/features/home/data/home_server_repository.dart`
- `lib/features/home/data/recommendation_choice_store.dart`
- `lib/features/home/presentation/home_server_dependencies.dart`
- `lib/features/home/presentation/home_server_view_model.dart`
- `lib/features/home/presentation/widgets/server_home_cards.dart`
- `lib/features/home/presentation/widgets/server_records_day.dart`
- `test/fakes/fake_home_server.dart`
- `test/features/home/home_server_repository_test.dart`
- `test/features/home/home_server_view_model_test.dart`
- `test/features/home/home_server_page_test.dart`
- `docs/project-context/previews/home-server-1.0.png`, `home-server-1.3.png`

기존 수정:

- `lib/app/onboarding/onboarding_flow.dart`: 서버 계정별 홈 의존성.
- `lib/app/shell/main_shell.dart`: 홈 활성/복귀 갱신 및 분석 이동.
- `lib/features/home/presentation/pages/home_page.dart`: 기존 홈 카드·요일·기록/일정 동작에 서버 데이터 연결.
- `lib/features/home/presentation/pages/workout_calendar_page.dart`: 날짜별 서버 기록과 기존 기기 기록을 함께 제공.
- `docs/project-context/README.md`: 최신 기능 상태.

## 검증과 남은 범위

Flutter 3.41.6 / Dart 3.11.4에서 정적 분석 문제 없음. 전체 테스트 **226개 통과, 실서버 2개 환경 미지정으로 미실행**. 신규 T8 테스트 15개는 API 쿼리·기간·인증, 기본 수동 유지, 날짜별 추천 선택, 복원 실패/과거 제한, 진행/완료 보호, 집계, 선택 읽기/쓰기 실패·재시도, 빠른 날짜 이동, 실제 홈 확인/취소·달력, 신규/오류 상태를 포함한다.

393×852 및 320×640/130% 글꼴 홈 서버 화면을 확인했다. 기존 골든 이미지는 갱신하지 않았고 기존 가입·홈·기록·일정·분석·목표·종목·추천 테스트가 통과했다. BE와 의존성은 수정하지 않았다. 실제 서버의 상태 동기화·통계와 기기 동작은 별도 검증이 필요하다.

다음은 T9의 실제 운동 시작/이어하기, 세트 기록, 휴식 타이머, 앱 재실행 복원이다. 기록 상세의 서버 세트 편집/삭제 등은 이후 T11에서 구현한다.
