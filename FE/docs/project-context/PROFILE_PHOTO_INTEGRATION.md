# 신체정보 수정·사진 관리 연결

기록일: 2026-10-26. 작업 위치: `/Users/yubin/StudioProjects/Project/FE`.

## 완료한 범위

T2 신체정보 수정과 T3 사진 업로드·관리를 구현했다. 실제 진입을 위해 마이페이지의 기본 화면을 함께 추가했다. 설정의 전체 기능(T12), 분석 진행/결과(T4), 전체 루틴 화면(T7), 커뮤니티는 이번에 완료한 범위가 아니다.

### 진입과 화면

- 로그인 후 홈의 알림 옆 `…` 메뉴를 마이페이지 아이콘으로 교체했다. 하단 내비게이션 항목은 추가하지 않았다.
- 마이페이지에는 계정 요약·현재 신체정보·운동 목적·주 운동 횟수·운동 기간·사진 데이터 관리·로그아웃이 있다. 닉네임 변경·동의 관리·탈퇴·처리방침은 T12에서 확장한다.
- 신체정보를 저장하면 마이페이지와 앱의 계정 상태에 즉시 반영한다. 로그아웃은 확인 후 기존 로그인 흐름으로 돌아가며, 실패 시 홈에서 다시 시도할 수 있다.
- 공통 색상·글꼴·둥근 카드·고정 하단 버튼을 사용했다. 기존 가입 설문의 3단계 배치는 유지했다. 수정 모드에서만 수치 칸을 한 줄씩 배치해 소수점 값·단위·큰 글씨가 겹치지 않게 했다.

### 신체정보 수정

- 기존 설문 UI를 `ProfileFormController`를 통해 재사용한다. 가입 동작은 OnboardingViewModel, 수정 동작은 ProfileEditViewModel이 담당한다.
- 서버 저장소는 GET으로 현재 값을 읽고 수정은 PATCH를 사용한다. 미등록 상태는 빈 입력으로 시작하며, 최초 POST가 PROFILE_ALREADY_EXISTS일 때만 PATCH로 전환한다.
- 기존에 저장된 정확한 주 1~7회를 수정 화면에서 보존한다. 가입 화면의 범위 버튼과 6+→6 규칙은 그대로다. 수치 범위·소수 첫째 자리·선택 누락을 검사한다.
- 저장 실패 시 입력을 유지한다. 서버 입력 오류는 해당 수치·선택 항목에 표시하고 하단 버튼은 고정한다. 알 수 없는 enum은 오류로 앱을 종료하거나 임의의 정상 값으로 바꾸지 않는다.
- `routine_refresh_recommended`가 true이면 재생성 확인 창을 띄운다. 사용자가 동의한 경우만 최신 완료 분석을 조회하여 `POST /routines`를 호출한다. 완료 분석이 없거나 실패하면 안내한다. 이 동작은 로컬의 직접 만든 일정을 바꾸거나 추천을 자동 적용하지 않는다. 전체 추천 선택·복원 UI는 T7/T8에서 구현한다.

### 사진 관리

- 현재 체형 사진을 3열·3:4 목록으로 보여 주고 정면/측면을 촬영하거나 앨범에서 선택한다. 추가 가능한 수는 최대 20장이다.
- 실제 파일 내용으로 JPG/PNG를 확인하고 기존 전처리를 이용해 EXIF 회전을 픽셀에 반영·긴 변 1024px 이하 JPEG로 변환한 뒤 multipart로 업로드한다. 인증 헤더와 JPEG 파트 타입을 보낸다.
- 업로드 실패 시 선택 사진을 유지하여 재시도할 수 있다. 취소·권한 오류·형식·용량·개수·동의 오류를 처리한다. 업로드 완료 후 앱이 만든 임시 사진 사본을 정리한다.
- 개별/전체 삭제는 확인 후 수행한다. 전체 삭제의 deleted_count/skipped_count를 구분하고 처리 중인 사진은 남겨 둔다. 분석 결과는 사진 삭제와 별도로 남는다는 안내를 제공한다.
- 목록 조회 시 새 서명 URL을 받고, 앱 복귀·당겨서 새로고침·이미지 오류 버튼·만료 임박 확인으로 갱신한다. 목록 조회 실패 시 불확실한 상태로 추가·삭제를 진행하지 않는다.
- 네이티브 사진 선택 복원에는 요청 주인 정보를 추가했다. 사진 관리에서 선택한 사진을 가입 분석 사진으로 잘못 복원하지 않도록 기존 가입용 복원과 계정별 사진 관리용 복원을 구분한다.
- 서버 모드는 계정의 서버 사진 저장소를 사용한다. 로컬 미리보기는 계정별로 분리된 앱 세션 안의 메모리 목록을 사용하며, 앱을 완전히 다시 시작한 뒤의 사진 복원·서버 동기화를 제공하지 않는다. 기존 온보딩 사진·운동 일정/기록의 저장 형식은 변경하지 않았다.

## 검증

- 시작 기준: 전체 테스트 138개 통과, 실제 서버 테스트 2개 미실행. 작업 시작 때 Git 작업 폴더는 깨끗했다.
- 최종: `flutter analyze` 문제 없음, 전체 `flutter test` **160개 통과**, 실제 서버 테스트 **2개 미실행**. Flutter 3.41.6 / Dart 3.11.4 사용.
- 서버 계약·PATCH/POST 충돌 전환·입력 보존·정확한 주 4회 복원·검증 실패·추천 재생성 선택/실패를 검증했다.
- 전처리 후 업로드·실패 재시도·20장 한도·목록 오류·개별/부분 삭제·서버 오류·인증 multipart·실제 JPEG EXIF 회전을 검증했다.
- 마이페이지→수정→사진 관리, 로그아웃 실패 재시도, 320px 폭과 130% 글꼴을 검증했다. 새 화면 검토 이미지를 생성해 수치 겹침과 카드 정렬을 확인했다.
- 기존 로그인·가입·홈·일정·달력 및 기존 화면 비교 테스트가 통과했다. 기존 기준 이미지는 갱신하지 않았다.
- `git diff --check` 통과. 백엔드·확정 API 문서·패키지 의존성을 수정하지 않았다. 커밋·Push는 실행하지 않았다.

실제 기기의 카메라 권한/프로세스 복원 및 서버 업로드·삭제는 테스트 서버와 기기에서 추가 검증해야 한다. 이번 결과는 가짜 저장소·HTTP 모의 응답·파일 변환 및 위젯 테스트의 결과다.

## 검토 이미지

- [마이페이지](previews/my-page.png)
- [마이페이지: 작은 화면·큰 글꼴](previews/my-page-large-text.png)
- [신체정보 수정](previews/profile-edit.png)
- [신체정보 수정: 작은 화면·큰 글꼴](previews/profile-edit-large-text.png)
- [사진 관리](previews/photo-management.png)
- [사진 관리: 작은 화면·큰 글꼴](previews/photo-management-large-text.png)

## 다음 단계

T4 분석 입력의 실제 업로드 연결, 진행·결과·기록 화면을 구현하고 T5 목표 체형으로 이어간다. 마이페이지 전체 설정·커뮤니티 등 이후 범위는 기존 계획대로 남아 있다. 개인정보 처리방침 URL을 임의로 만들지 않는다.

## 이번 작업 파일

- `docs/project-context/previews/my-page-large-text.png`
- `docs/project-context/previews/my-page.png`
- `docs/project-context/previews/photo-management-large-text.png`
- `docs/project-context/previews/photo-management.png`
- `docs/project-context/previews/profile-edit-large-text.png`
- `docs/project-context/previews/profile-edit.png`
- `lib/app/onboarding/onboarding_flow.dart`
- `lib/app/onboarding/onboarding_view_model.dart`
- `lib/app/shell/main_shell.dart`
- `lib/core/media/image_picker_service.dart`
- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/photos/data/local_photo_repository.dart`
- `lib/features/photos/data/models/body_photo.dart`
- `lib/features/photos/data/photo_preparer.dart`
- `lib/features/photos/data/photo_repository.dart`
- `lib/features/photos/data/server_photo_repository.dart`
- `lib/features/photos/presentation/pages/photo_management_page.dart`
- `lib/features/photos/presentation/photo_management_view_model.dart`
- `lib/features/profile/data/local_profile_repository.dart`
- `lib/features/profile/data/models/body_profile.dart`
- `lib/features/profile/data/profile_repository.dart`
- `lib/features/profile/data/server_profile_repository.dart`
- `lib/features/profile/presentation/my_page_view_model.dart`
- `lib/features/profile/presentation/pages/my_page.dart`
- `lib/features/profile/presentation/pages/profile_edit_page.dart`
- `lib/features/profile/presentation/pages/profile_form_page.dart`
- `lib/features/profile/presentation/profile_edit_view_model.dart`
- `lib/features/profile/presentation/profile_form_controller.dart`
- `lib/features/routines/data/routine_refresh_repository.dart`
- `lib/features/routines/data/server_routine_refresh_repository.dart`
- `lib/ui/core/widgets/management_page.dart`
- `test/app/onboarding_flow_test.dart`
- `test/fakes/fake_profile_photo_repositories.dart`
- `test/features/photos/photo_management_test.dart`
- `test/features/photos/photo_preparer_test.dart`
- `test/features/profile/my_page_test.dart`
- `test/features/profile/profile_edit_test.dart`
