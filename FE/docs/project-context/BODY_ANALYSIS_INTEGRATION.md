# 체형분석 연결 (T4) 및 프로필 버튼 — 2026-10-26

실제 작업 위치는 `/Users/yubin/StudioProjects/Project/FE`다. 기존 T2/T3 변경 위에 선택적으로 추가했으며 Git 커밋·Push는 실행하지 않았다.

## 구현한 흐름

- 홈 프로필 아이콘은 알림과 같은 22×22 아이콘 영역, 36×36 최소 버튼 크기, 동일한 외곽선을 사용한다. 기본 Material 터치 영역도 서로 같다.
- 실제 Figma 파일 `pdQ0Dn4jcL4m7FC0hXAQ7x`의 `03 체형분석 입력`(269:265), `05 홈`(665:360)을 읽어 확인했다. 입력은 기존 카드·색·글꼴·고정 하단 버튼을 재사용한다. 별도 진행/결과/기록 디자인이 없고 `04` 프레임은 비어 있어 같은 디자인 규칙으로 새 화면을 만들었다. Figma 파일 자체는 변경하지 않았다.
- 서버 가입의 신체정보 다음 단계와 메인 분석 탭에서 정면(필수)·측면(선택) 사진을 선택한다. 기존 카메라/앨범, JPEG·회전·크기 전처리와 공통 인증 API를 사용한다. 글 분석은 MVP 서버 작업에서 제외되어 안내를 표시한다. 기존 로컬 가입 미리보기 흐름은 보존한다.
- 사진 업로드 성공 ID를 기억해 분석 요청 실패 때 성공한 사진을 다시 업로드하지 않는다. POST 분석은 `photo_id`, 선택 `side_photo_id`와 `goal_body_id`를 전달한다. 실패 시 사진 선택은 유지한다. 분석 요청 성공 후에는 중복 POST 대신 같은 분석 번호를 조회한다.
- 진행 상태는 즉시 조회하고 pending이면 2초 간격으로 최대 60초 확인한다. 긴 요청도 남은 대기 시간으로 제한한다. 이탈/앱 비활성화 시 조회를 멈추며 재개·재확인은 같은 ID로 진행한다. 네트워크 오류·대기 초과·HTTP 200 failed 상태를 구분한다.
- 진행 중인 ID는 계정별로 저장한다. 목록에서 기존 pending을 찾아 409 충돌도 이어서 확인한다. 완료/실패가 확인된 경우에만 저장 ID를 지우고, 조회 오류 때에는 유지한다. 기록 저장이 실패해도 이미 시작된 서버 작업을 실패한 신규 요청으로 취급하지 않는다.
- 결과에는 균형 점수·체형·5개 측정 항목·자세 판정·목표 비교를 표시한다. null은 0으로 바꾸지 않으며 측정 불가 사유를 한국어로 표시한다. 시험용 `stub-v0` 응답은 시험 결과라고 표시한다. 모르는 상태/판정값도 완료·양호로 추정하지 않는다.
- 분석 기록은 최신순 페이지 조회·더 보기·새로고침·실패 재시도·빈 상태·상세 진입을 제공한다. 메인 분석 탭과 마이페이지에서 접근한다.
- ‘맞춤 루틴 만들기’ 확인을 누른 경우에만 해당 결과의 분석 ID로 POST한다. 생성된 서버 루틴 제목·날짜·운동을 요약 표시한다. 예정 추천 교체 가능성을 확인 창에 알리며 직접 만든 주간 일정·기록을 자동 교체하지 않는다.
- 한도 소진 시 추가 업로드/요청을 막고 서버 초기화 시각을 표시한다. 동의/신체정보 부족 응답에는 기존 동의·온보딩 상태를 다시 확인하는 경로를 제공한다. 인증 만료는 기존 공통 API 처리를 따른다.

## 변경 파일

기존 파일 수정:

- `lib/features/home/presentation/pages/home_page.dart`: 프로필 아이콘 영역·외곽선.
- `lib/features/body_analysis/presentation/pages/onboarding_analysis_page.dart`: 입력 폼 재사용, 선택적 기록/목표/안내, 글 분석 지원 여부. 기본 로컬 가입 화면 동작·기준 이미지는 유지.
- `lib/features/body_analysis/presentation/pages/analysis_entry_page.dart`: 메인/서버 가입용 입력 진입과 진행·기록 연결.
- `lib/app/onboarding/onboarding_view_model.dart`: 기존 입력을 공통 폼 인터페이스로 노출.
- `lib/app/onboarding/onboarding_flow.dart`: 계정별 분석 의존성, 서버 가입 연결.
- `lib/app/shell/main_shell.dart`: 분석 탭과 마이페이지 기록 연결.
- `lib/features/profile/presentation/pages/my_page.dart`: 분석 기록 행 추가.
- `test/app/main_shell_test.dart`, `test/app/onboarding_flow_test.dart`: 실제 탭 동작과 스크롤 가능한 로그아웃 회귀 테스트.

신규 파일:

- `lib/features/body_analysis/data/models/body_analysis.dart`: 분석 요청/결과/목록/한도/목표 응답 모델.
- `lib/features/body_analysis/data/analysis_repository.dart`: 분석·기록·목표 참조·루틴 생성 계약.
- `lib/features/body_analysis/data/server_analysis_repository.dart`: 최신 OpenAPI 경로 연결.
- `lib/features/body_analysis/data/local_analysis_repository.dart`: 가짜 분석 수치를 만들지 않는 로컬 미리보기.
- `lib/features/body_analysis/data/analysis_pending_store.dart`: 계정별 진행 ID 저장.
- `lib/features/body_analysis/presentation/analysis_dependencies.dart`: 화면 의존성 묶음.
- `lib/features/body_analysis/presentation/analysis_form_controller.dart`: 기존 가입 폼과 신규 분석 폼의 공통 입력 계약.
- `lib/features/body_analysis/presentation/analysis_input_view_model.dart`: 선택/업로드/요청/재시도/한도/목표 참조.
- `lib/features/body_analysis/presentation/analysis_run_view_model.dart`: 진행 조회·중단·재개·명시적 루틴 생성.
- `lib/features/body_analysis/presentation/pages/analysis_run_page.dart`: 진행/오류/결과 및 추천 요약.
- `lib/features/body_analysis/presentation/pages/analysis_history_page.dart`: 기록 목록.
- `test/fakes/fake_analysis_repository.dart`: 분석 테스트용 저장소.
- `test/features/body_analysis/analysis_flow_test.dart`: 업로드 재사용, 한도, 409, 조회 제한/재개, 늦은 응답 무시, nullable 처리.
- `test/features/body_analysis/server_analysis_test.dart`: 경로·요청 키·목록 페이지·분석 ID 확인.
- `test/features/body_analysis/analysis_pages_test.dart`: 입력 오류 시 버튼 고정, 기록 진입, 결과/명시적 생성, 아이콘 크기·외곽선, 작은 화면/큰 글꼴.
- `docs/project-context/previews/analysis-input-1.0.png`, `analysis-input-1.3.png`, `analysis-result-1.0.png`, `analysis-result-1.3.png`: 신규 화면 QA 이미지. 기존 골든 기준 이미지는 갱신하지 않았다.

## 검증과 남은 작업

- Flutter 3.41.6 / Dart 3.11.4에서 `flutter analyze`: 문제 없음.
- 전체 `flutter test`: **174개 통과, 실서버 2개 환경 미지정으로 미실행**. 기존 인증·가입·홈·주간 일정·사진/신체정보 회귀와 신규 T4 테스트 포함.
- 393×852 및 320×640·130% 글꼴 위젯 테스트와 신규 입력/결과 PNG 배치를 확인했다. 실제 기기 카메라·권한·백그라운드 복원, 실서버/메일/AI의 응답 품질과 배포 환경은 이번 자동 테스트로 확인한 범위가 아니다.
- 의존성·BE·네이티브 설정·기존 로컬 일정 저장 형식은 변경하지 않았다.
- 목표 체형 신규 등록/교체/삭제는 다음 T5다. 현재는 서버에 등록되어 분석 완료된 목표만 선택 가능하며, 목표 없이도 현재 체형 분석을 요청할 수 있다.
- 생성한 추천의 주간 일정 연결·상세 편집/운동 실행은 이후 루틴 작업이다. 이번 단계는 결과에서 명시적 생성과 응답 요약까지다.
