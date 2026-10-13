# 홈 기능 선택적 통합 보고서

## 대상과 기준

- 개발 원본: `/Users/yubin/StudioProjects/FE`
- 통합 대상: `/Users/yubin/StudioProjects/Project/FE`
- Git 저장소 루트: `/Users/yubin/StudioProjects/Project`
- 작업 브랜치: `main`, 시작 HEAD `8ba3a80`
- 작업 시작 시 Git 미커밋 변경 없음. 커밋·Push·브랜치 전환·원격 변경을 수행하지 않음.

전체 프로젝트 복사 대신 홈에 필요한 파일과 기존 연결 지점만 선택적으로 통합했다. 파일 삭제는 수행하지 않았다.

## 통합한 기능

- 홈 화면의 인사말, 고정 주간 예시 계획, 날짜 선택·오늘로 복귀·휴식일 구분.
- 예시 루틴 목록과 전체 4종목 보기, 종목별 완료·전체 루틴 완료 후 기록 보기.
- 기기 내 운동 미리보기의 시작·이어하기·취소·종목 전환 확인·완료.
- 무게 0~500kg, 횟수 1~100, 세트 수 1~20의 검사와 저장 시 일관된 정수 변환.
- 계정 이메일별 운동 기록 저장·복원, 날짜별 기록·세트·볼륨·연속일·미리보기 목표 집계.
- 기록 조회 실패/손상 시 쓰기 차단·재조회, 기존 저장값 보호.
- 과거·미래 날짜의 조회 전용 처리. 앱 복귀·분 단위 날짜 갱신과 6시간 경과 운동 자동 중단. 자동 중단은 통계에서 제외하며 저장 실패 시 추가 쓰기 차단.
- 자정을 넘어 완료한 운동은 시작 날짜로 보존하고 해당 날짜 기록을 표시.
- 사용자가 제공한 홈·알림 SVG, 홈·분석·기록·인공지능 코치·커뮤니티 5개 탭.
- 운동 기록 카드를 준비 중 카드보다 먼저 배치. 기존 로그아웃 콜백 유지.

실제 AI·맞춤 식단·할인권·서버 운동 API는 연결되지 않았으며 개발용 예시/준비 상태로 유지했다. 기존 원격/사용자 저장 데이터를 프로젝트 사이에 복사하지 않았다.

## 충돌 및 호환성 조정

1. 대상의 로그인·회원가입·신체정보·체형분석 코드에는 원본과 별도 차이가 있었다. 홈 구현에 필요하지 않아 복사하지 않았다. `lib/app/onboarding`, `lib/features/auth`, `lib/features/profile`, `lib/features/body_analysis`, `lib/ui/core`, `lib/app/vitality_app.dart`는 기존 바이트를 보존했다.
2. 대상의 기존 공통 `ReferenceStyle`과 `ReferenceButton`이 새 홈과 호환됨을 확인해 그대로 재사용했다. 기존 Noto/Inter/CapstoneUI 폰트·Cupertino 의존성·전체 기존 에셋을 삭제하거나 교체하지 않았다.
3. 소스의 전역 한국어 로케일 설정을 대상 `VitalityApp`에 덮어쓰지 않았다. 한국어 달력은 홈의 날짜 선택기에만 `Localizations.override`로 적용했다. 기존 인증 화면의 로케일/디자인은 유지된다.
4. `MainShell`의 기존 홈·분석·기록 탭 순서와 화면·로그아웃 인자를 유지하면서 새 탭 두 개만 추가했다. 분석/기록 업무 화면을 다른 구현으로 바꾸지 않았다. 기존 경로와 인증 진입 흐름도 유지했다.
5. `pubspec.yaml`에는 `flutter_localizations` SDK와 SVG 두 개의 등록만 추가했다. `pubspec.lock`에는 새 SDK 패키지와 `intl 0.20.2`만 추가됐으며 기존 의존성을 제거하거나 업그레이드하지 않았다.
6. 기존 온보딩 테스트를 통째로 교체하지 않았다. 홈 인사 문구·계정 메뉴를 통한 로그아웃·홈 탭 탐색의 바뀐 UI 선택자만 수정했다. 기존 입력 검증·가입 동의·저장·복원 검사는 유지했다.
7. 개발 원본은 분석 입력 없이 홈으로 이동하도록 바뀌어 있으나, 대상의 기존 체형분석 검증은 이번 통합에서 유지했다. 홈 화면은 대상의 기존 정상 온보딩 완료 또는 로그인 뒤 표시된다. 분석 입력을 건너뛰는 동작은 기존 기능 변경이므로 자동으로 가져오지 않았다.

## 변경 파일 목록

### 기존 파일 수정

- `lib/features/home/presentation/pages/home_page.dart`
- `lib/app/shell/app_bottom_nav.dart`
- `lib/app/shell/main_shell.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `test/app/main_shell_test.dart`
- `test/app/onboarding_flow_test.dart`

### 새 파일 추가

- `lib/features/home/presentation/home_view_model.dart`
- `lib/features/home/data/home_preview_repository.dart`
- `assets/icons/home.svg`
- `assets/icons/bell.svg`
- `test/app/home_test.dart`
- `test/app/home_fixes_test.dart`
- `test/app/home_integration_test.dart`
- `test/fakes/fake_home_repository.dart`
- `docs/frontend-architecture/previews/home.png`
- `docs/frontend-architecture/HOME_INTEGRATION.md`

## 검증 결과

검증 명령은 모두 `/Users/yubin/StudioProjects/Project/FE`를 작업 디렉터리로 실행했다.

- 통합 전 `flutter test`: 기존 테스트 **51개 통과**.
- 통합 후 `flutter analyze`: 오류·경고 없음.
- 통합 후 `flutter test`: **69개 통과**. 기존 51개 테스트와 새 홈/달력 통합 테스트 18개 포함.
- 기존 로그인·회원가입·신체정보·체형분석·추가 창의 golden 기준 이미지는 재생성하지 않았으며 원래 기준으로 통과했다.
- 새 홈 기준 이미지는 개발 프로젝트에서 가져온 것으로 화면 비교 테스트 통과.
- 별도 통합 테스트로 기본 앱 로케일이 영어인 상태에서도 홈 달력만 한국어이며, 닫으면 원래 로케일이 유지됨을 확인했다.
- 기존 인증·온보딩의 필수 동의·입력·다음 단계·로그아웃 실패 재시도·재실행 복원 테스트 통과.
- `flutter build ios --simulator --no-codesign`: 대상 프로젝트의 iOS 시뮬레이터 빌드 성공.
- `git diff --check`: 공백 오류 없음.
- SHA-256 비교: 기존 파일 삭제 없음, 보호 대상 생산 코드 변경 없음. Git 변경은 모두 `FE/` 내부이며 BE·다른 팀 작업 영역은 변경하지 않음.
- Android 빌드·실제 기기 카메라·실제 서버 인증/AI는 이번 검증 대상이 아니며 확인했다고 주장하지 않는다.

## 백업

통합 전 대상의 소스·테스트·에셋·pubspec·기준 화면 백업은 `/private/tmp/fe-github-integration-before.tar.gz`, 파일 해시 목록은 `/private/tmp/fe-integration-before-manifest.json`에 보관했다. 프로젝트의 파일을 복구해야 할 경우 전체를 덮어쓰지 말고 필요한 파일만 선택적으로 복원해야 한다.
