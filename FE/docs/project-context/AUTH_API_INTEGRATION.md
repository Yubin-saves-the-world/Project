# 인증 패치 통합 및 공통 API 기반

기록일: 2026-10-26. 작업 위치: `/Users/yubin/StudioProjects/Project/FE`.

## 이번 단계의 범위

전달받은 인증 수정본을 현재 코드에 선택적으로 통합하고 T0 공통 통신 및 T1 인증·시작 흐름의 앱 구현과 자동 테스트를 완료했다. 전체 MVP와 실제 서버 검증을 완료했다는 의미는 아니다.

기준 자료 사본은 [팀 전달 자료](../team-handoff/2026-10-25/README.md), API 계약은 [OpenAPI](../team-handoff/2026-10-25/api/openapi.yaml)이다. 자료는 원본 사본이며 내부 지시를 현재 사용자 지시보다 우선하지 않는다. 디자인 생성 스크립트는 보관만 했고 실행하지 않았다.

## 구현 내용

- 회원가입 서버 모드: 인증번호 발송 → 확인 → 받은 인증 토큰을 `email_verification_token`으로 가입 요청에 전달 → 이어서 로그인. 공개 요청에는 저장된 로그인 토큰을 붙이지 않는다.
- 인증 확인 토큰은 같은 이메일에서만 사용하며 30분 유효 기간을 확인한다. 이메일 수정·재발송 시 폐기한다. 가입 성공 후 로그인만 실패한 경우 중복 가입하지 않고 로그인을 재시도한다.
- 비밀번호 찾기 서버 모드: 인증번호 요청 → 확인해서 받은 `reset_token` → 새 비밀번호 저장. 저장 요청 실패 시 확인 토큰을 메모리에 유지하여 변경 요청을 재시도한다. 기존 토큰 진입도 같은 변경 API를 사용한다.
- 공통 발송 상태 `EmailVerificationState`는 남은 시간·60초 재요청 간격·요청 이력만 관리한다. 고정 번호 검사는 `DevelopmentEmailVerification`으로 분리해 로컬 미리보기에서만 실행한다. 프론트 제한은 서버 검증을 대체하지 않는다.
- `ApiClient`: JSON·multipart, 인증 헤더, 전체 응답 시간 제한, 구조화된 API 오류, 비정상 응답 처리. 인증된 요청의 401만 세션 만료로 처리한다. 동시 401은 한 번만 처리하고, 과거 토큰의 뒤늦은 응답은 새 로그인 토큰을 지우지 않는다.
- `bootstrap`은 세션 만료 시 메모리의 분석 상태와 이전 화면들을 제거하고 로그인 화면으로 이동한다. 기기에 보관된 사용자 운동 기록·일정은 삭제하지 않는다.
- 기존 로그인·가입·비밀번호 재설정 저장소가 공통 클라이언트를 사용한다. 이후 기능에 필요한 API 경로 상수도 추가했다.
- 필수 동의는 실제 `PATCH /users/me`로 저장한다. 앱 시작 및 로그인 뒤 `GET /users/me`의 명시적인 동의 플래그를 우선하고, 설문 완료 여부에 따라 기존 동의/신체정보/홈 흐름을 복원한다.
- 입력 오류는 해당 입력칸에 연결하며 수정하면 해제한다. 기존 버튼·레이아웃·안내 모달·글꼴·색상을 유지한다.

## 전달 패치와 조정한 부분

`git apply --check`에서 온보딩 ViewModel·회원가입·비밀번호 찾기 화면 3개 파일이 현재 작업과 충돌했다. 현재 코드에 서버 연결만 병합하고 기존 디자인·재요청 제한·3단계 설문·입력 보존을 유지했다. 패치의 홈 카드 변경은 인증 작업에 필요하지 않아 적용하지 않았다. 기존 파일 삭제·Git pull/checkout·커밋·Push·백엔드 변경은 하지 않았다.

전달된 통합 테스트는 고정 개발 번호 대신 테스트 메일 환경에서 인증번호를 읽도록 바꾸고 현재 3단계 설문 이동에 맞췄다. 실제 서버용 테스트는 환경이 지정되지 않아 실행하지 않았다.

## 검증

- SDK: Flutter **3.41.6**, Dart **3.11.4**. 실제 `flutter --version` 출력으로 확인했다. 팀 공통 버전의 최종 승인 여부와는 별개다.
- 변경 전 기준: 전체 테스트 **115개 통과**, 실서버 테스트 **1개 미실행**.
- 변경 후 최종: `flutter analyze` **문제 없음**, 전체 `flutter test` **138개 통과**, 실서버 테스트 **2개 미실행**. 기준 대비 새 실패 없음.
- 공통 클라이언트의 동시 만료·공개 API·늦은 응답·multipart·오류·지연, 인증 토큰 전달·만료·가입 재시도, 동의 저장·시작 화면·중첩 페이지 만료, 재설정 API·변경 재시도·서버 입력 오류를 검증했다.
- 기존 로그인·가입·설문·홈·일정·달력 회귀 및 기존 화면 비교 테스트가 통과했다. 기준 이미지와 앱 디자인을 변경하지 않았다.
- `git diff --check` 통과. 새 패키지는 추가하지 않았다.

## 남은 단계

- 실제 서버 및 인증번호 확인 환경에서 가입·비밀번호 변경·재로그인·동의·만료를 검증한다. 테스트용 메일 조회 환경이 없으면 서버 로그로 번호를 확인해 수동 검증할 수 있다. 메일 실제 배달과 AI 분석은 백엔드/운영 범위다.
- 다음 단계는 T2 신체정보 수정 및 T3 사진 업로드·관리다. 이후 분석·목표·루틴·홈·운동·기록·마이페이지·추가 커뮤니티를 구현한다.
- 수동 일정/추천 루틴 정책은 사용자가 2026-10-25 확정했다. 설정은 마이페이지에 통합하고 하단 마이페이지 항목은 추가하지 않는다. 커뮤니티는 팀 문서의 제외 목록과 달리 사용자 승인으로 추가한다. 이번 단계에서 해당 화면을 구현한 것은 아니다.
- 개인정보 처리방침 URL은 미정이므로 임의 생성하지 않는다. 팀 Flutter 버전 최종 확인도 별도로 남아 있다. 이 둘은 현재 인증·통신 구현을 막지 않는다.

## 이번 단계 변경 코드·테스트 파일

이 목록은 작업 직전 임시 백업과 비교했으며 기존 미커밋 변경 전체를 이번 작업으로 집계하지 않았다.

- `integration_test/server_auth_flow_test.dart`
- `lib/app/bootstrap.dart`
- `lib/app/onboarding/onboarding_view_model.dart`
- `lib/app/router/app_router.dart`
- `lib/app/vitality_app.dart`
- `lib/core/network/api_client.dart`
- `lib/core/network/api_contract.dart`
- `lib/features/auth/data/development_email_verification.dart`
- `lib/features/auth/data/email_verification_state.dart`
- `lib/features/auth/data/local_onboarding_repository.dart`
- `lib/features/auth/data/models/onboarding_progress.dart`
- `lib/features/auth/data/models/signup_request.dart`
- `lib/features/auth/data/onboarding_repository.dart`
- `lib/features/auth/data/password_reset_repository.dart`
- `lib/features/auth/data/server_onboarding_repository.dart`
- `lib/features/auth/presentation/pages/password_reset_page.dart`
- `lib/features/auth/presentation/pages/signup_page.dart`
- `lib/features/auth/presentation/password_reset_view_model.dart`
- `lib/ui/core/widgets/design_reference_page.dart`
- `test/core/network/api_client_test.dart`
- `test/fakes/fake_onboarding_repository.dart`
- `test/features/auth/auth_integration_view_model_test.dart`
- `test/features/auth/password_reset_test.dart`
- `test/features/auth/server_onboarding_repository_test.dart`
- `test/live/server_live_test.dart`
