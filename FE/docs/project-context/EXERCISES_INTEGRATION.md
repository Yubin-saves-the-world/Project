# 운동 종목 조회 (T6) — 2026-10-26

실제 프로젝트 `/Users/yubin/StudioProjects/Project/FE`에서 작업했다. 이번 변경은 커밋·Push하지 않았다. 앞선 T5는 `75c0ca3`으로 Push되어 있다.

## 구현 범위

- 마이페이지 → 운동 종목, 홈 일정 만들기/수정 → 종목 정보에서 조회한다. 새 하단 메뉴는 추가하지 않았다.
- `GET /api/exercises`에 이름 검색(q), 부위(target_part), 기구(equipment), 난이도 상한(difficulty), page/page_size=20을 전달한다. 검색은 300ms 디바운스와 30자 제한을 적용한다.
- 부위 6개·기구 4개·난이도 1~5 이하 필터, 검색어 지우기, 필터 초기화, 결과 수, 빈 상태, 새로고침, 더 보기, 실패 재시도를 제공한다. 필터 변경 시 먼저 시작한 늦은 응답은 무시한다. 더 보기 실패 때 기존 목록과 페이지는 유지한다.
- 종목을 누르면 `GET /api/exercises/{id}`의 상세 설명·부위·기구·난이도·사용자 운동 기간 기준 min_sets/max_sets를 표시한다. 서버가 준 권장 세트를 임의의 클라이언트 값으로 덮어쓰지 않는다. 모르는 부위·기구·난이도나 없는 세트 정보에는 대체 문구를 사용한다.
- media_url이 없으면 시범 영상 미등록 안내를 표시한다. 유효한 HTTP(S) 영상 링크는 사용자 탭으로 외부 앱/브라우저에서 열고 실패 시 재시도 안내를 제공한다. 임의 스킴·자격 정보가 포함된 URL은 열지 않는다. 앱 안에서 영상을 직접 재생하는 플레이어는 이번 범위에 없다.
- 영상 링크를 위해 Flutter 공식 게시자 패키지 `url_launcher ^6.3.3`과 플랫폼 의존성 7개를 추가했다. 기존 패키지를 일괄 업그레이드하지 않았다. 별도 canLaunchUrl 조회 없이 launchUrl 결과/예외를 처리한다. 패키지 문서: https://pub.dev/packages/url_launcher
- 새 네이티브 플러그인을 반영하려면 실행 중인 앱을 중지하고 다시 빌드/실행한다. 실제 기기에서 링크 앱이 열리는 동작은 별도 확인이 필요하다.

## 기존 데이터와 로컬 미리보기

서버의 exercise_id와 기존 수동 일정의 배열 번호는 서로 다르다. 이번 단계에서는 기존 workoutCatalog와 주간 일정/기록 저장 형식을 변경하지 않았다. 조회한 종목을 기존 배열 번호로 자동 변환하거나 일정에 삽입하지 않는다. 기존 일정의 종목 선택·세트·횟수 편집은 그대로 유지한다.

로컬 미리보기는 팀 BE의 `V1_1__seed_exercises.sql`에 있는 24개 종목의 이름·부위·기구·난이도·설명을 사용한다. 로컬 저장소의 ID는 미리보기에서만 쓰며 실제 서버 ID로 간주하지 않는다. 공백 무시 이름 검색과 동일한 필터/페이지를 제공한다. 운동 기간을 변경하면 예시 권장 세트도 현재 프로필로 다시 계산하며, 미리보기라는 문구를 화면에 표시한다.

자유 운동 시작(POST /workout-logs), 세트 기록·타이머는 T9에서 연결한다. 이번 T6는 종목 목록·검색·상세·영상 조회까지다. 다음은 T7 추천 루틴의 주간·상세 화면, 이후 T8 홈 서버 연결이다.

## 변경 파일

신규:

- `lib/features/exercises/data/models/exercise.dart`
- `lib/features/exercises/data/exercise_repository.dart`
- `lib/features/exercises/data/server_exercise_repository.dart`
- `lib/features/exercises/data/local_exercise_repository.dart`
- `lib/features/exercises/presentation/exercise_list_view_model.dart`
- `lib/features/exercises/presentation/pages/exercise_list_page.dart`
- `lib/features/exercises/presentation/pages/exercise_detail_page.dart`
- `test/fakes/fake_exercise_repository.dart`
- `test/features/exercises/exercise_repository_test.dart`
- `test/features/exercises/exercise_list_test.dart`
- `test/features/exercises/exercise_pages_test.dart`
- `docs/project-context/previews/exercise-list-1.0.png`, `exercise-list-1.3.png`

기존 수정:

- `lib/app/onboarding/onboarding_flow.dart`: 서버/로컬 종목 저장소 조합.
- `lib/app/shell/main_shell.dart`: 목록 진입 경로.
- `lib/features/profile/presentation/pages/my_page.dart`: 운동 종목 행.
- `lib/features/home/presentation/pages/home_page.dart`, `weekly_routine_editor.dart`: 일정 편집의 종목 정보 연결. 목록에서 돌아오면 입력 초안 유지.
- `pubspec.yaml`, `pubspec.lock`: 영상 링크 패키지.
- `lib/features/exercises/README.md`, `docs/project-context/README.md`: 구현 상태.

## 검증

Flutter 3.41.6 / Dart 3.11.4에서 정적 분석 문제 없음. 전체 테스트 **200개 통과, 실서버 2개 환경 미지정으로 미실행**. 신규 T6 테스트는 11개이며 API 요청 키/인증·목록/검색/필터·페이지 오류/응답 경합·영상 열기 실패/재시도·일정 초안 보존을 포함한다. 기존 가입·홈·목표·분석·사진/신체정보 회귀도 통과했다.

393×852 및 320×640/130% 글꼴에서 새 목록 화면과 상세 진입을 검증하고 목록 PNG를 확인했다. 기존 골든 이미지는 갱신하지 않았다. 실제 서버 데이터·시범 영상 재생 및 네이티브 앱 빌드는 이번 자동 테스트로 검증하지 않았다. BE 코드는 읽기만 했고 수정하지 않았다.
