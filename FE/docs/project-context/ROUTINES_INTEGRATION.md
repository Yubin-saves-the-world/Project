# 추천 루틴 주간·상세 (T7) — 2026-10-26

실제 FE 프로젝트에서 구현했다. 앞선 T6는 `79b33d3`으로 Push되었고, 이번 단계는 커밋·Push하지 않았다.

## 구현한 기능

- 마이페이지의 ‘추천 루틴’에서 월~일 주간 목록을 연다. 이전/다음 주 이동·새로고침·오류 재시도를 제공한다. GET /api/routines/weekly에는 계산한 월요일을 week_start로 전달한다.
- 주간 응답은 7개 날짜와 연속된 월~일인지 확인한다. 누락된 데이터를 임의의 휴식일로 채우지 않는다. 루틴 없는 날은 ‘추천 루틴 없음’으로 표시하여 실제 수동 일정/휴식일과 구별한다.
- 날짜는 한국 날짜 기준의 오늘을 사용하고, 주간 이동 계산은 UTC 기반 달력 날짜로 정규화하여 기기 시간대·일광절약시간의 날짜 이동 영향을 피한다.
- 날짜별 루틴 제목·부위·예상 시간·예정/완료/건너뜀 상태·완료 종목 수를 표시한다. 알 수 없는 상태나 잘못된 진행 수치는 완료/0으로 추정하지 않는다.
- 루틴을 누르면 GET /api/routines/{id}로 상세를 읽는다. 종목 수행 순서·세트·횟수·무게·휴식 시간·추천 이유·종목 완료 여부를 표시한다. target_weight_kg가 null이면 ‘직접 입력’으로 표시하며 임의의 무게를 만들지 않는다.
- 상세의 ‘운동 정보 보기’는 실제 exercise_id로 기존 T6 상세/영상 링크 화면에 연결한다. 기존 로컬 배열 번호로 바꾸지 않는다.
- 확인 창 이후 PATCH /api/routines/{id}에 skipped/planned를 전송한다. 완료 루틴은 변경할 수 없고, 건너뛴 루틴의 되돌리기는 오늘/미래만 가능하다. 요청 중 중복 변경과 이탈을 막고 버튼 영역을 유지한다.
- 상태 변경 실패 시 기존 정보를 보존하되 재조회 전에는 추가 변경을 막는다. 상세에서 돌아오면 주간 목록을 다시 읽어 진행/상태를 갱신한다. 세션 만료는 공통 API 처리, 신체정보 부족은 기존 상태 확인 경로를 따른다.
- 분석 결과의 기존 명시적 루틴 생성 API를 재사용한다. 생성 응답의 ID로 ‘루틴 상세 보기’를 열고, 생성된 날짜가 속한 ‘주간 루틴 보기’로 연결한다. 주간 조회만으로 재생성하지 않는다.
- 신체정보 수정 후 사용자가 확인하여 새로 생성한 경우에도 마이페이지 알림의 ‘보기’로 주간 추천을 확인할 수 있다.
- 로컬 미리보기는 추천을 만들어내지 않고 빈 7일 목록과 서버 연결 제한을 표시한다. 직접 만든 일정·반복 원본·기존 기록 및 홈 디자인은 변경하지 않았다.

## 이번 범위와 다음 작업

추천을 직접 만든 일정과 교체하는 UI, 같은 날짜에 수동 일정이 있을 때 서버 추천을 자동으로 건너뛰는 정책, 홈 휴식일 해제와 서버 복원 동기화는 T8에서 연결한다. 이번 상세 화면의 건너뛰기·되돌리기는 추천 루틴의 상태만 변경한다.

운동 시작·세트 기록·휴식 타이머는 T9다. 이번 단계에서 작동하지 않는 운동 시작 버튼이나 가짜 완료 처리를 추가하지 않았다.

## 변경 파일

신규:

- `lib/features/routines/data/models/routine.dart`
- `lib/features/routines/data/routine_repository.dart`
- `lib/features/routines/data/server_routine_repository.dart`
- `lib/features/routines/data/local_routine_repository.dart`
- `lib/features/routines/presentation/routine_week_view_model.dart`
- `lib/features/routines/presentation/routine_detail_view_model.dart`
- `lib/features/routines/presentation/pages/routine_week_page.dart`
- `lib/features/routines/presentation/pages/routine_detail_page.dart`
- `test/fakes/fake_routine_repository.dart`
- `test/features/routines/routine_repository_test.dart`
- `test/features/routines/routine_view_model_test.dart`
- `test/features/routines/routine_pages_test.dart`
- `docs/project-context/previews/routine-week-1.0.png`, `routine-week-1.3.png`, `routine-detail.png`

기존 수정:

- `lib/app/onboarding/onboarding_flow.dart`: 계정별 서버/로컬 루틴 저장소와 종목 저장소 조합.
- `lib/app/shell/main_shell.dart`, `lib/features/profile/presentation/pages/my_page.dart`: 주간 추천 진입과 재생성 후 보기.
- `lib/features/body_analysis/presentation/analysis_dependencies.dart`, `pages/analysis_run_page.dart`: 생성된 루틴 상세/주간 연결.
- `lib/features/routines/README.md`, `docs/project-context/README.md`: 현재 구현 상태.

## 검증

Flutter 3.41.6 / Dart 3.11.4에서 정적 분석 문제 없음. 전체 테스트 **211개 통과, 실서버 2개 환경 미지정으로 미실행**. 신규 T7 테스트 11개에는 API 요청/인증·월요일/연도 경계·불완전 응답·주간 응답 경합·변경 제한/오류 복구·분석 생성 ID 연결·확인/취소·운동 상세 연결이 포함된다.

393×852 및 320×640/130% 글꼴 UI 테스트와 새 주간·상세 이미지를 확인했다. 기존 골든 이미지는 갱신하지 않았다. 실제 서버의 생성/상태 변경과 기기 동작은 별도 검증이 필요하다. BE·의존성·기존 로컬 일정 저장 형식은 변경하지 않았다.
