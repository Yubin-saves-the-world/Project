# 마이페이지 계정·동의·탈퇴 연동 (T12)

2026-10-27 · 실제 작업 대상 `/Users/yubin/StudioProjects/Project/FE`.

T11은 `fae27ad` (`feat: 운동 기록 달력 및 상세 편집 구현`)로 origin/main에 커밋·Push했다. 아래 T12는 다음 작업으로 구현했으며 아직 커밋·Push하지 않았다.

## 구현 범위

기존 마이페이지에 세 하위 화면을 연결했다. 별도의 설정/마이페이지 내비게이션 탭은 추가하지 않았다. 기존 신체정보·목표·사진·추천 루틴·종목·분석 기록·로그아웃 진입은 유지한다.

### 내 계정 정보

`GET /api/users/me`로 이메일·닉네임·가입일을 읽고, `PATCH /api/users/me`에 닉네임 필드만 보내 수정한다. 2~20자 검사, NICKNAME_DUPLICATED/필드 오류의 입력칸 표시, 통신 실패 후 재조회, 중복 제출 방지를 제공한다. 이메일은 읽기 전용이며 null도 표시할 수 있다. 저장 후 마이페이지 헤더와 홈의 계정 정보도 갱신한다.

### 사진·AI 동의 관리

사진 이용·AI 처리 스위치는 서버가 확정한 값을 표시한다. 철회는 먼저 확인하고 필요한 한 필드만 PATCH한다. 통신 실패를 성공으로 표시하지 않고 재조회로 복구한다.

- 사진 철회: 새 업로드 제한과 기존 사진이 자동 삭제되지 않는다는 안내를 제공한다. 사진 관리로 이동해 사용자가 직접 삭제한다.
- AI 철회: 진행 중 분석이 취소되고 새 분석/루틴 생성이 제한되며 기존 결과는 계속 조회할 수 있음을 확인한다.
- 재동의: 해당 스위치만 true로 변경한다. 이용약관/개인정보 동의를 임의 변경하지 않는다.
- 현재 사진 관리와 별도로 목표 사진 관리도 제공한다. 목표 원본은 조회/삭제만 가능하고 업로드/분실 사진 복원은 제공하지 않는다. 목표 등록과 AI 처리는 기존 목표 화면을 사용한다. PHOTO_IN_USE와 일괄 삭제의 skipped 안내는 기존 처리를 유지한다.
- 사진 관리의 CONSENT_REQUIRED에는 실제 동의 관리 이동을 제공한다. 기존 분석/목표의 접근 확인 동작도 현재 서버 동의를 확인하고 동의 관리로 연결한다.

공통 API에 선택적인 인증 요청 전 훅을 추가하고, 기능 정책은 별도 ConsentRequestGuard에 둔다. 현재 계정 동의를 매번 읽어 사진 POST와 AI 생성/목표 변경을 네트워크 전 차단한다. 분석/목표 입력은 사진을 업로드하기 전에 AI 동의도 먼저 확인한다. GET(기록/결과/사진), 사진/목표 삭제, 재동의 PATCH, 공개 인증 요청은 이 제한으로 막지 않는다. 서버 검증도 그대로 사용한다.

### 회원 탈퇴

안내 확인 체크 → 최종 확인 대화상자 후 `DELETE /api/users/me`를 호출한다. 서버 삭제가 성공해야 토큰과 해당 계정의 기기 정보를 정리한다. 서버 실패 시 기기 기록을 지우지 않는다.

원격 삭제 성공 후 기기 정리가 실패하면 계정이 이미 삭제되었음을 표시하고 **기기 정보 정리 다시 시도**를 제공한다. 이때 DELETE를 반복하지 않는다. 정리가 끝나면 메모리 가입/신체정보/사진 입력과 계정별 의존성 캐시를 비우고 로그인으로 돌아간다. 일반 로그아웃은 기존 동작을 유지하며 운동 기록/수동 일정을 삭제하지 않는다.

## 동의 복원 정책 보완

문서에는 consent_completed=false일 때 동의 우선 진입과, 철회 후 기존 기록 조회 허용이 함께 있다. 이를 구분했다.

- 신규 가입/기존 미동의 로컬 데이터/필수 동의가 불명확한 계정: 기존 동의 화면 우선 동작을 유지한다.
- **서버가 consent_completed=false라고 명시하고, 신체정보 등록이 완료되었으며 사진 또는 AI 동의가 철회된 계정**: 기존 프로필을 읽어 홈/저장 기록으로 복귀할 수 있다. 재동의를 강제하거나 철회 값을 true로 바꾸지 않는다. 새 쓰기에는 동의 제한을 적용한다.

CurrentUser의 기본 진입 분류 자체는 유지하며 실제 OnboardingFlow에서 이 명시적인 철회 예외를 처리한다. 관련 기존 가입 동의 테스트는 약화하지 않았다.

## 기기 데이터 소유 범위

기존 이메일 계정의 저장 키는 바꾸지 않았다. 이메일이 없는 계정은 서버 user_id를 OnboardingAccount에 보관하고 `user:<id>`를 기기 데이터 소유 키로 사용한다. 이메일을 UI에 임의 생성하지 않는다.

탈퇴 시 해당 소유 키에 속하는 수동 일정·기기 기록·휴식일 설정·추천 선택·분석 pending·운동 세트/타이머 초안을 정리한다. 로컬 가입 미리보기 데이터도 소유자가 일치할 때만 제거한다. 다른 계정의 키와 공통 앱 설정은 보존하며 전체 preferences clear는 사용하지 않는다.

새 사진 사본은 onboarding/analysis/goal/photos의 계정별 폴더에 저장한다. 사진 선택을 시작할 때 소유자를 고정하고 같은 소유자만 분실 선택을 복원한다. 탈퇴는 해당 계정 폴더와 확인된 현재 입력 사본만 정리하며 갤러리 원본은 삭제하지 않는다.

**레거시 제한:** 이전 버전의 공용 사진 폴더에서 소유자를 증명할 수 없는 사본과, 회원 ID 없이 빈 이메일만 사용한 공용 데이터는 다른 계정 자료일 수 있어 일괄 삭제/이관하지 않는다. 현재 입력으로 소유가 확인되는 레거시 사진은 정리하지만 출처 불명 자료를 전부 지웠다고 보장하지 않는다. 운영 배포 전 T13에서 레거시 정리/이관 정책을 별도로 확인해야 한다. 네이티브 파일 시스템의 실기기 검증도 남아 있다.

## 변경 파일

새 코드:

- `lib/features/settings/data/account_repository.dart`: 내 정보 GET/PATCH/DELETE.
- `lib/features/settings/data/account_data_cleaner.dart`: 소유자별 preferences 정리.
- `lib/features/settings/data/consent_request_guard.dart`: 현재 동의에 따른 새 쓰기 제한.
- `lib/features/settings/presentation/account_settings_dependencies.dart`, `account_settings_view_model.dart`: 공유 상태, 오류/재조회, 탈퇴 단계별 재시도.
- `lib/features/settings/presentation/pages/account_settings_pages.dart`: 계정 정보·동의 관리·탈퇴.

기존 연결:

- `lib/app/onboarding/onboarding_flow.dart`, `onboarding_view_model.dart`, `lib/app/shell/main_shell.dart`: 계정 상태 반영, 동의 관리 이동, 탈퇴 후 로그인/캐시 정리.
- `lib/core/network/api_client.dart`: 선택적 인증 요청 전 훅.
- `lib/core/media/image_picker_service.dart`: 소유자별 사본과 해당 계정 사본 정리.
- `lib/features/auth/data/models/onboarding_progress.dart`, `server_onboarding_repository.dart`: 회원 ID/소유 키와 철회 후 복원 구분.
- `lib/features/home/presentation/pages/home_page.dart`: 이메일 없는 계정의 저장 소유 키.
- `lib/features/profile/presentation/pages/my_page.dart`: 세 하위 화면과 공유 계정 상태.
- `lib/features/body_analysis/presentation/analysis_dependencies.dart`, `analysis_input_view_model.dart`: 업로드 전 AI 동의 확인.
- `lib/features/goal_body/presentation/goal_dependencies.dart`, `goal_view_model.dart`: 목표 저장 전 AI 동의 확인.
- `lib/features/photos/presentation/photo_management_view_model.dart`, `pages/photo_management_page.dart`: 동의 관리 이동, current/goal 조회·삭제 구분.

테스트/문서:

- `test/fakes/fake_account_settings.dart`.
- `test/features/settings/account_settings_test.dart`, `account_settings_pages_test.dart`, `account_settings_integration_test.dart`.
- `test/features/auth/server_onboarding_repository_test.dart`: 철회 후 프로필/기록 복원 추가.
- `docs/project-context/previews/account-{info,privacy}-{1.0,1.3}.png`, `account-delete-1.3.png`.
- 현재 보고서·프로젝트 인수인계·settings README.

## 검증과 다음 단계

2026-10-27 · Flutter 3.41.6 / Dart 3.11.4.

- 최종 정적 분석: 문제 없음.
- 전체 `flutter test --no-pub`: **298개 통과, 실서버 2개 환경 미지정으로 미실행**.
- 신규 19개 항목: 설정 단위 8·화면 6·기능 연결 4·기존 인증 저장소 철회 복원 1. API 계약/최소 PATCH, 닉네임 중복/범위, 비관적 동의 상태, 원격 삭제 후 정리 재시도, 다른 계정 보존, 공개 인증/기존 GET 허용, AI 업로드 전 차단, 목표 사진 유형, 가입 입력 정리, 실제 앱 재생성 시 철회 유지, 이메일 없는 회원 ID 분리를 검증했다.
- 393×852 및 320×640/130% 글꼴 계정/동의/탈퇴 화면과 오류 시 버튼 위치를 확인했다. 기존 골든 이미지는 변경하지 않았다. BE·의존성·Figma 파일은 변경하지 않았다. 기존 실패 진단 이미지는 이번 변경에 포함하지 않는다.
- 실제 서버의 동의 철회/작업 취소/탈퇴·서버 사진 삭제 및 네이티브 파일 정리는 실서버·실기기로 검증한 결과가 아니다. 계약과 가짜 HTTP/저장소/선택기 및 위젯으로 검증했다.

다음은 T13 전체 흐름 점검이다. 실제 서버·기기 점검 가능한 환경과 위 레거시 정책을 확인하고 신규 가입→온보딩→분석→추천→운동→기록→설정 흐름을 종합 검증한다. 커뮤니티는 사용자가 추가한 별도 구현 범위로 남아 있다.


## 후속 T13 점검 (2026-10-27)

T12는 이후 `e321fe9`로 커밋·Push했다. [T13 보고](MVP_FLOW_VERIFICATION.md)에서 iOS 시뮬레이터 네이티브 preferences/사진 처리·정리와 실제 앱 화면의 계정 탈퇴 복귀를 검증했다. HTTP는 테스트 계약 픽스처이며 실제 서버 탈퇴 검증은 아니다.

소유가 일치하는 옛 가입 JSON 안에 남은 사진 경로도 정리 콜백으로 전달하도록 보완했다. 사본 정리가 실패하면 JSON을 지우지 않아 재시도할 수 있다. 소유 정보가 없는 공용 파일을 임의 삭제하지 않는 제한은 유지한다.
