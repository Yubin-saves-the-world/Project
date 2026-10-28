# 목표 체형 관리 (T5) — 2026-10-26

실제 FE 프로젝트(`/Users/yubin/StudioProjects/Project/FE`)에 구현했다. 이번 단계에서는 커밋·Push를 실행하지 않았다. 앞선 T2~T4는 `1ba2b8b`로 이미 Push된 상태다.

## 진입과 동작

- 분석 입력의 ‘목표 체형’ 카드 또는 마이페이지의 ‘목표 체형’ 행에서 연다. 새 하단 메뉴는 추가하지 않았다. 제목 없는 기존 분석 입력과 현재 스크롤 정책은 유지한다.
- 사진 없이 1~200자 설명만 등록할 수 있다. 사진만 또는 사진+설명도 가능하다. 비어 있는 입력과 200자 초과는 저장 전에 차단한다.
- 사진은 기존 JPEG/회전/크기 전처리 후 `POST /photos`에 `type=goal`, `side=front`로 업로드한다. 카메라·앨범·선택 제거 및 계정별 `goal:<email>` 복원을 기존 사진 선택 서비스로 제공한다.
- `POST/GET /goal-bodies`, `PATCH/DELETE /goal-bodies/{id}`를 공통 인증 ApiClient로 연결했다. 404 `GOAL_NOT_FOUND`는 빈 상태다.
- 사진 목표는 pending/done/failed를 구분하며 2초 간격, 최대 60초 조회한다. 백그라운드/화면 이탈에서 멈추고 재개 시 서버의 현재 목표를 다시 조회한다. 조회 오류를 분석 실패로 표시하지 않는다. 시간 초과 후 수동 재확인이 가능하다.
- 설명만 있는 done 목표도 비교 선택이 가능하다. pending/failed/미인식 상태와 저장하지 않은 변경 사항이 있는 목표는 비교 선택할 수 없다. ‘목표 없이 분석’도 제공한다.
- 서버가 사진에서 특징을 추출한 뒤 원본을 삭제하는 계약에 맞춰, 요청 수락 후 선택 사진의 로컬 사본도 정리하고 저장 후에는 summary/description만 표시한다. 저장된 목표 사진이 보관된 것으로 표시하거나 삭제된 원본 미리보기를 만들지 않는다.
- 저장 실패 시 입력/사진을 보존하고 성공한 업로드는 재시도에 사용한다. 업로드 후 1시간이 지났거나 404/410이면 임시 업로드 ID를 재사용하지 않는다. 404 수정 오류는 재조회 후 삭제된 목표 대신 새 등록으로 복구할 수 있다.
- 409 `GOAL_ALREADY_EXISTS`는 현재 목표를 불러오되 자동 PATCH로 덮어쓰지 않는다. 사용자에게 충돌을 알리고 변경 저장 확인을 거치게 한다.
- 교체와 삭제는 확인 창을 제공한다. 처리 중 목표도 삭제 가능하며 서버 계약상 처리 취소를 요청한다. 지난 분석의 비교 결과는 유지된다고 안내한다. 새 목표로 비교하려면 분석을 다시 요청해야 한다.
- 분석 시작 전에 선택한 목표가 여전히 존재하고 done인지 재확인한다. 목표 삭제/교체/처리 중이면 사진 업로드 전에 재선택을 안내한다.
- 동의/신체정보 부족은 기존 상태 확인 경로를 제공하며 401은 기존 전역 세션 만료 처리를 따른다.
- 로컬 미리보기는 계정별 앱 세션 메모리에 설명 목표만 저장한다. 사진 목표 입력을 비활성화하고 이 제한을 표시한다. 가짜 AI 요약·사진 분석 수치를 만들지 않는다.

## 변경 파일

신규:

- `lib/features/goal_body/data/models/goal_body.dart`
- `lib/features/goal_body/data/goal_repository.dart`
- `lib/features/goal_body/data/server_goal_repository.dart`
- `lib/features/goal_body/data/local_goal_repository.dart`
- `lib/features/goal_body/presentation/goal_dependencies.dart`
- `lib/features/goal_body/presentation/goal_view_model.dart`
- `lib/features/goal_body/presentation/pages/goal_body_page.dart`
- `test/fakes/fake_goal_repository.dart`
- `test/features/goal_body/goal_view_model_test.dart`
- `test/features/goal_body/server_goal_test.dart`
- `test/features/goal_body/goal_page_test.dart`
- `docs/project-context/previews/goal-body-1.0.png`, `goal-body-1.3.png`

기존 수정:

- `lib/app/onboarding/onboarding_flow.dart`: 공통 사진 저장소와 계정별 목표 의존성.
- `lib/app/shell/main_shell.dart`, `lib/features/profile/presentation/pages/my_page.dart`: 목표 관리 진입.
- `lib/features/body_analysis/presentation/analysis_dependencies.dart`: 목표 의존성 전달.
- `lib/features/body_analysis/presentation/analysis_input_view_model.dart`: 선택한 목표 재확인.
- `lib/features/body_analysis/presentation/pages/analysis_entry_page.dart`: 등록/관리/비교 선택 연결.
- `lib/features/body_analysis/presentation/pages/onboarding_analysis_page.dart`: 실제 목표 기능의 사진/설명 지원에 맞는 카드 제목. 기존 로컬 가입 기본값은 보존.
- `lib/features/body_analysis/data/models/body_analysis.dart`: 설명 전용 목표의 비교 안내.
- `lib/features/goal_body/README.md`, `docs/project-context/README.md`: 현재 상태 기록.

## 검증 범위

Flutter 3.41.6 / Dart 3.11.4에서 정적 분석 문제 없음. 전체 테스트 **189개 통과, 실서버 2개 환경 미지정으로 미실행**. 목표 API·상태/재시도·입력/충돌/삭제·비교 선택 신규 15개와 기존 가입·홈·사진/신체정보·분석 회귀를 포함한다.

393×852와 320×640/130% 글꼴에서 버튼/오류/확인 창을 검증했고 목표 화면 이미지를 확인했다. 기존 골든 이미지는 이번 단계에 갱신하지 않았다. 실제 서버의 목표 원본 삭제·AI 응답·실기기 카메라/권한/앱 복원은 별도 검증이 필요하다.

BE·네이티브 설정·의존성·기존 로컬 주간 일정/기록 저장 형식은 변경하지 않았다. 다음 단계는 T6 운동 종목 조회 및 이후 루틴·홈 서버 연결이다.
