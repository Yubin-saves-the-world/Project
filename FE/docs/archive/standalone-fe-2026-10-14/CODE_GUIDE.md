# 초보 개발자를 위한 현재 코드 안내

현재 프로젝트 코드를 기준으로 설명한다. 이 문서는 앱 동작을 바꾸지 않고 코드 읽는 방법을 정리한 것이다.

## 1. 먼저 이해할 네 가지 역할

앱의 코드를 한 파일에 모두 넣지 않고, 역할별로 나눠 놓았다.

| 역할 | 하는 일 | 현재 코드 예시 |
| --- | --- | --- |
| Page: 화면 | 입력칸과 버튼을 보여주고 사용자 동작을 받는다. | `SignupPage` |
| ViewModel: 처리와 상태 | 입력값·진행 단계·처리 중 여부를 관리하고 저장을 요청한다. | `OnboardingViewModel` |
| Repository: 저장 통로 | 데이터를 불러오고 저장한다. | `LocalOnboardingRepository` |
| 데이터 모델 | 관련 정보를 하나의 객체로 묶는다. | `SignupRequest`, `BodyProfile` |

예를 들어 키를 저장하는 과정은 아래처럼 이어진다.

```text
사용자가 신체정보 화면에서 키를 입력
    → ProfileFormPage의 입력 컨트롤러가 값을 가진다
    → model.height에 입력값을 반영한다
    → ‘다음’을 누르면 입력과 선택 항목을 검사한다
    → OnboardingViewModel.submitProfile()을 호출한다
    → BodyProfile 객체를 만든다
    → Repository.saveProfile()로 저장한다
    → step이 2로 바뀐다
    → OnboardingFlow가 체형분석 화면을 보여준다
```

페이지는 화면을 담당하고, 저장 방법은 Repository가 담당한다. 그래서 나중에 저장소를 서버 API로 바꿀 때 화면 코드를 전부 다시 만들 필요가 줄어든다.

## 2. 폴더를 읽는 방법

```text
lib/
├── main.dart       앱이 시작되는 파일
├── app/            앱 시작, 화면 전환, 가입 상태, 하단 탭
├── features/       로그인·신체정보·사진 등 기능별 코드
│   └── 기능 이름/
│       ├── data/           데이터 객체와 저장 관련 코드
│       └── presentation/   실제 화면과 화면용 위젯
├── core/           입력 검사, 사진 처리, API 계약 등 공통 기능
└── ui/core/        공통 색상·폰트·버튼·입력칸·화면 틀

assets/             앱에 포함할 로고·아이콘·폰트
test/              기능과 화면을 자동으로 확인하는 테스트
docs/              기획·API·구조 설명과 화면 비교 자료
tools/             Figma 자료를 읽는 작업 도구
```

`features/auth`는 로그인과 회원가입 기능이고, `features/profile`은 신체정보 기능이다. 기능 이름 아래의 `data`와 `presentation`을 구분하면 파일을 찾기 쉽다. README만 있는 일부 기능 폴더는 이후 개발을 위한 자리다.

## 3. 앱이 시작되는 순서

```text
main.dart
  → bootstrap.dart
  → VitalityApp
  → AppRouter
  → OnboardingFlow
  → 저장 상태에 맞는 로그인·가입·홈 화면
```

1. [main.dart](../lib/main.dart)의 `main()`이 `bootstrap()`을 호출한다.
2. [bootstrap.dart](../lib/app/bootstrap.dart)는 Flutter를 준비하고 `runApp()`으로 앱을 실행한다.
3. [vitality_app.dart](../lib/app/vitality_app.dart)는 `MaterialApp`을 만든다. 여기서 앱 전체 테마와 첫 경로를 정한다. 기본 첫 경로는 `/login`이다.
4. [app_router.dart](../lib/app/router/app_router.dart)는 경로에 맞는 위젯을 연결한다. `/login`과 `/signup`은 모두 `OnboardingFlow`를 만들지만 시작 설정이 다르다.
5. [onboarding_flow.dart](../lib/app/onboarding/onboarding_flow.dart)는 ViewModel을 만들고 `initialize()`로 저장된 정보를 읽는다.

로그인에서 가입으로 이동하거나 가입 중 ‘다음’을 누를 때는 주로 같은 `OnboardingFlow` 안의 상태를 바꾼다. 가입 단계마다 별도의 URL로 이동하는 구조는 아니다.

## 4. 어떤 화면을 보여줄지 결정하는 코드

`OnboardingFlow`는 다음 순서로 상태를 확인한다.

| 상태 | 표시하는 화면 |
| --- | --- |
| `loading == true` | 저장 정보를 불러오는 로딩 화면 |
| `showLogin == true` | 로그인 |
| 로그인된 기존 계정이 필수 동의를 마치지 않음 | 동의 확인 |
| 로그인 상태이고 `completed == true` | 홈과 하단 탭 |
| `step == 0` | 회원가입 |
| `step == 1` | 신체정보 |
| `step == 2` | 체형분석 입력 |

`step`은 가입 화면의 번호이고, `showLogin`은 로그인 화면을 따로 보여줄지 결정하는 값이다.

**`completed`와 `onboardingCompleted`는 다르다.** 현재 `OnboardingProgress.onboardingCompleted`는 신체정보가 저장되어 있는지를 뜻한다. 같은 가입 흐름에서는 신체정보 다음에 체형분석 입력을 보여준다. 이후 앱을 다시 시작하면 로그인된 상태와 저장된 신체정보를 확인해 홈으로 들어갈 수 있다.

## 5. 각 화면에서 하는 일

### 로그인: LoginPage

파일: [login_page.dart](../lib/features/auth/presentation/pages/login_page.dart)

- 이메일·비밀번호 입력을 받는다.
- 입력 형식을 확인한 뒤 `model.login()`을 호출한다.
- 로그인 실패 시 오류와 입력값을 유지한다.
- 회원가입을 누르면 `model.openSignup()`을 호출한다.
- 소셜 로그인과 비밀번호 찾기 버튼은 현재 미연결 안내를 보여준다.

화면의 `_email`, `_password`는 `TextEditingController`다. 입력칸의 내용을 읽고 관리하는 객체다.

### 회원가입: SignupPage

파일: [signup_page.dart](../lib/features/auth/presentation/pages/signup_page.dart)

‘다음’을 눌렀을 때 다음 순서로 동작한다.

1. 컨트롤러에서 닉네임·이메일·비밀번호·인증번호를 읽는다.
2. `Form.validate()`로 입력 형식을 검사한다.
3. 개발용 인증번호를 검사한다.
4. 하단 창에서 필수 동의 4개를 받는다.
5. 동의를 마쳤다면 `model.submitAccount()`를 호출한다.
6. ViewModel이 가입 저장과 로그인 처리를 완료하고 `step = 1`로 바꾼다.
7. `OnboardingFlow`가 신체정보 화면을 표시한다.

인증번호 검사는 이 페이지와 `DevelopmentEmailVerification`에 있고, `submitAccount()` 자체에는 OTP 검사가 없다. ViewModel의 `submitAccount()`는 계정 입력과 필수 동의를 검사하고 저장을 담당한다.

현재 개발용 인증번호는 `123456`이다. 발급한 이메일에 적용되며 5분 동안 유효하다. 오입력 5회 이후에는 재발급해야 한다. `Timer`는 화면의 남은 시간 표시를 갱신하고, 실제 만료 여부는 발급 시각으로 검사한다. 이메일을 바꾸면 기존 코드와 시간이 초기화된다.

### 신체정보: ProfileFormPage

파일: [profile_form_page.dart](../lib/features/profile/presentation/pages/profile_form_page.dart)

- 키·몸무게·나이를 직접 입력한다. `170·65·18`은 회색 힌트이므로 실제 저장값이 아니다.
- 성별·운동 목적·주 운동 횟수·운동 기간을 선택한다. 새 가입에서는 모두 미선택이다.
- 숫자 입력은 `TextFormField`, 선택 항목은 `FormField<T>`로 검사한다.
- 미선택 메시지는 해당 선택 항목 아래에 표시한다. 선택하면 메시지가 사라진다.
- ‘다음’은 하단에 고정하고 입력 영역만 스크롤한다.

화면의 범위 선택은 저장할 때 아래 정수로 연결된다.

| 선택 문구 | 저장값 |
| --- | ---: |
| 0 ~ 1회 | 1 |
| 2 ~ 3회 | 3 |
| 4 ~ 5회 | 5 |
| 6~7회 | 7 |

`model.submitProfile()`은 저장 전 한 번 더 검사한다. 키는 100~250cm, 몸무게는 30~250kg, 나이는 10~100세 정수 범위다.

### 체형분석 입력: OnboardingAnalysisPage

파일: [onboarding_analysis_page.dart](../lib/features/body_analysis/presentation/pages/onboarding_analysis_page.dart)

- 사진 카드를 누르면 정면·측면 사진 입력창을 연다.
- 각 사진의 추가 버튼을 누르면 카메라 또는 앨범을 선택한다.
- 글로 설명하기를 누르면 최대 500자 입력창을 연다.
- 목표 체형 사진은 선택 사항이다.
- 현재 ‘분석 시작’은 서버 미연결 상태에서 분석을 건너뛰고 홈으로 이동한다. 실제 분석 준비에 필요한 사진·글 검증은 ViewModel의 `finish(prepareAnalysis: true)` 경로에 남아 있다.
- 입력을 저장하고 완료하면 홈으로 이동한다. 현재는 AI 결과를 생성하지 않는다. 분석 입력이 없어도 버튼을 눌러 홈으로 이동할 수 있다.
- 버튼은 하단에 고정하고 오류가 있는 내용 영역만 스크롤한다.

### 홈과 하단 탭

파일: [main_shell.dart](../lib/app/shell/main_shell.dart)

`MainShell`은 홈·분석·기록 탭을 묶는다. `IndexedStack`은 선택한 탭을 보여주면서 다른 탭의 위젯도 유지한다. 현재 홈은 루틴 예시·요일 선택·기기 내 운동 기록 미리보기·달력·로그아웃을 제공한다. 하단은 홈·분석·기록·인공지능 코치·커뮤니티 5개 탭이며 나머지 업무 기능은 준비 화면이다.

## 6. 상태가 바뀌면 화면은 어떻게 바뀌나?

핵심 파일: [onboarding_view_model.dart](../lib/app/onboarding/onboarding_view_model.dart)

ViewModel은 `ChangeNotifier`를 상속한다. `_notify()`가 내부에서 `notifyListeners()`를 호출하면, 이를 듣고 있는 `ListenableBuilder`가 화면을 다시 구성한다.

```text
사용자 동작
  → ViewModel의 메서드 호출
  → 값 변경
  → _notify()
  → ListenableBuilder가 최신 값으로 화면을 다시 구성
```

모든 변수 변경이 자동으로 이 알림을 보내는 것은 아니다. 예를 들어 숫자를 입력하면 컨트롤러와 `model.height`를 바꾸고, 입력칸은 자체적으로 갱신한다. 화면 전체 전환이 필요할 때 ViewModel의 메서드가 알림을 보낸다.

| 중요한 값 | 뜻 |
| --- | --- |
| `loading` | 처음에 저장 정보를 읽는 중 |
| `busy` | 가입·로그인·저장·사진 처리 등을 수행 중 |
| `step` | 회원가입 0, 신체정보 1, 체형분석 2 |
| `error` | 처리 오류 메시지. 없으면 `null` |
| `showLogin` | 로그인 화면을 보여줄지 여부 |
| `progress` | 계정·신체정보·분석 입력·로그인 상태를 모은 객체 |
| `analysis` | 현재 체형분석 입력 |
| `gender`, `goalType`, `frequency`, `experienceLevel` | 선택한 값. 선택 전에는 `null` |

`_run()`은 여러 작업이 공유하는 처리 틀이다. 처리 중이면 중복 요청을 막고, `busy`를 켜고, 작업을 기다리고, 실패를 `error`로 바꾼 뒤, 마지막에 `busy`를 끄고 화면에 알린다. 그래서 각각의 저장 메서드에 로딩·오류 처리를 반복해서 적지 않아도 된다.

`_registrationPendingLogin`은 가입 저장 후 로그인만 실패한 경우 가입 요청을 다시 하지 않고 로그인을 재시도하기 위한 값이다.

## 7. 메모리에 있는 값과 저장된 값 구분하기

`ViewModel`과 `TextEditingController`의 값은 현재 실행 중인 앱이 사용하는 입력값이다. 앱을 종료한 뒤에도 남길 정보는 Repository를 통해 저장해야 한다.

현재 [local_onboarding_repository.dart](../lib/features/auth/data/local_onboarding_repository.dart)는 `SharedPreferencesAsync`에 JSON 문자열 하나를 저장한다. 저장 키는 `vitality.onboarding.preview.v1`이다.

```text
Dart 데이터 객체
  → toJson(): 키와 값으로 바꾸기
  → jsonEncode(): 문자열로 바꾸기
  → 기기에 저장

기기에서 문자열 읽기
  → jsonDecode(): 키와 값으로 복원
  → fromJson(): Dart 데이터 객체로 복원
```

이 저장소는 한 계정 흐름을 테스트하는 개발용 저장소다. 새 가입을 저장하면 해당 저장 키의 기존 내용은 새 가입 내용으로 교체된다. 여러 계정을 보관하는 실제 회원 DB가 아니다.

### 로그아웃 후 가입 정보가 비어 있는 이유

1. Repository는 저장된 로그인 상태를 `false`로 바꾼다. 기존 계정·신체정보는 유지한다.
2. ViewModel은 화면에 사용할 `progress`와 가입 초안을 비운다.
3. 앱을 다시 열어도 로그아웃 상태라면 이전 계정 정보를 가입 입력칸으로 복사하지 않는다.
4. 기존 계정으로 로그인하면 저장소의 정보를 다시 읽어 복원한다.

즉, 기존 계정의 저장 정보와 새로운 회원가입의 입력값을 구분한다.

## 8. 데이터 모델은 무엇인가?

| 파일 | 묶어 놓은 정보 |
| --- | --- |
| `signup_request.dart` | 닉네임·이메일·비밀번호·필수 동의. 가입 요청에 사용 |
| `body_profile.dart` | 키·몸무게·나이·성별·운동 목적·횟수·기간 |
| `selected_photo.dart` | 사진 파일 경로와 크기, 사진 종류와 선택 경로 |
| `analysis_input.dart` | 사진/글 방식, 정면·측면·목표 사진, 설명 |
| `onboarding_progress.dart` | 저장된 계정, 신체정보, 분석 입력과 진행 상태 |
| `auth_session.dart` | 이후 서버 로그인 응답과 사용자 정보 형식 |

`enum`은 정해진 선택지다. 예를 들어 `Gender.male`과 `Gender.female`을 쓰면 성별을 자유로운 문자열로 적을 때 생기는 오타를 줄일 수 있다. `Gender.none`은 기존 데이터와의 호환을 위해 남아 있지만 현재 입력 화면에서는 선택할 수 없다.

`copyWith()`는 기존 객체의 일부 값만 바꾼 새 객체를 만든다. 사진 교체와 진행 상태 변경 등에 사용한다. 단, 모든 `copyWith()`가 `null` 삭제를 지원하는 것은 아니다. `OnboardingProgress.copyWith()`에서 `null`은 기존 값 유지이므로, 로그아웃 시 빈 `OnboardingProgress`를 새로 만든다. `AnalysisInput.copyWith(slot: ..., photo: null)`은 지정한 사진 삭제를 지원한다.

## 9. 사진 처리 순서

파일: [image_picker_service.dart](../lib/core/media/image_picker_service.dart), [image_preprocessor.dart](../lib/core/media/image_preprocessor.dart)

```text
사진 선택
 → JPG/PNG 형식 확인
 → 촬영 방향 보정
 → 긴 변이 1024px를 넘으면 축소
 → 품질 90의 JPEG로 변환
 → 변환 결과의 10MB 제한 확인
 → 앱 전용 폴더에 저장
 → 경로와 파일 크기를 SelectedPhoto로 반환
```

이미지 변환은 `compute()`로 별도 isolate에서 처리한다. 사진을 변환하는 동안 메인 화면 처리가 오래 막히는 것을 줄이기 위한 방식이다.

사진의 경로는 가입 정보의 JSON에 저장하고, 사진 파일 자체는 앱 전용 폴더에 저장한다. 사진을 교체하거나 삭제할 때는 앱이 만든 사본만 지운다. 앨범의 원본 사진을 삭제하지 않는다. Android에서 사진 선택 중 앱이 종료된 경우를 위한 복원 처리도 있다.

## 10. 공통 UI 파일

핵심 파일: [design_reference_page.dart](../lib/ui/core/widgets/design_reference_page.dart)

| 위젯/설정 | 역할 |
| --- | --- |
| `ReferencePage` | 흰색 화면, 폭 제한, 스크롤, 뒤로 버튼, 선택적으로 고정 하단 버튼 |
| `ReferenceTitle` | 로그인·가입 화면의 공통 제목 |
| `ReferenceField` | 라벨과 입력칸, 힌트, 입력 오류, 오른쪽 버튼 |
| `ReferenceButton` | 공통 파란 버튼과 처리 중 표시 |
| `ReferenceDivider` | 소셜 로그인 앞의 OR 구분선 |
| `ReferenceStyle` | 공통 글자 크기·줄 높이·서체와 색상 참조 |
| `AppTheme` | 팝업·하단 창·체크박스 등 앱 전체 스타일 |
| `AppColors` | 공통 색상 값 |

신체정보와 체형분석은 버튼을 `ReferencePage.footer`에 전달한다. 버튼이 스크롤 내용과 분리되어 있기 때문에 오류 메시지가 길어져도 아래로 밀리지 않는다.

`assets` 파일은 프로젝트에 놓는 것만으로 앱에 포함되지 않는다. `pubspec.yaml`에 등록해야 한다. 현재는 SVG 6개, PNG 2개와 CapstoneUI 폰트 두 파일을 앱에서 사용한다.

## 11. 자주 보이는 Dart·Flutter 문법

| 코드/용어 | 읽는 방법 |
| --- | --- |
| `Widget` | 화면을 구성하는 요소. 글자·버튼·페이지도 위젯 |
| `build()` | 현재 상태에 맞는 위젯 구성을 반환하는 메서드 |
| `StatelessWidget` | 자체적으로 변경 가능한 State 객체를 갖지 않는 위젯 |
| `StatefulWidget` | 컨트롤러·타이머·입력 여부 등 화면 전용 State를 갖는 위젯 |
| `initState()` | State가 만들어질 때 초기 설정을 하는 곳 |
| `dispose()` | 화면/객체가 제거될 때 컨트롤러·타이머·포커스 등을 정리하는 곳 |
| `setState()` | 해당 화면의 State 변경을 알리고 다시 구성하도록 요청 |
| `String?` | 문자열이거나 `null`일 수 있음 |
| `??` | 왼쪽이 `null`이면 오른쪽 값을 사용 |
| `!` | `null`이 아니라고 가정해 접근. 확인 없이 쓰면 오류 가능 |
| `final` | 변수에 다른 값을 다시 대입할 수 없음. 객체 내부까지 무조건 불변이라는 뜻은 아님 |
| `const` | 컴파일 시 정할 수 있는 상수 |
| `required` | 호출할 때 반드시 제공해야 하는 매개변수 |
| `_submit` | 현재 파일의 라이브러리 내부에서 쓰는 비공개 이름 |
| `Future<T>` | 나중에 완료되는 작업 결과의 타입 |
| `async` / `await` | 저장·사진 선택 등의 비동기 작업이 끝나기를 기다리는 문법 |
| `mounted` | 해당 State가 아직 화면 트리에 있는지 확인 |
| `GlobalKey<FormState>` | Form에 접근해 `validate()` 등을 호출하기 위한 키 |
| `validator` | 입력 검사 함수. 성공하면 `null`, 실패하면 오류 문구 반환 |
| `onPressed` / `onChanged` | 버튼 클릭 / 입력 변경 때 실행할 함수 |

`await`는 처리가 끝날 때까지 다음 줄의 진행을 기다리지만, 그동안 앱 전체를 강제로 멈추는 뜻은 아니다. 다만 무거운 계산을 메인 isolate에서 계속 수행하면 화면이 느려질 수 있어서 사진 변환에는 `compute()`를 사용한다.

## 12. 기능을 수정할 때 찾아갈 곳

| 바꾸려는 내용 | 우선 확인할 파일 |
| --- | --- |
| 로그인 입력칸·버튼 배치 | `login_page.dart` |
| 가입 입력·인증번호·동의 창 | `signup_page.dart` |
| 인증번호 시간·오입력 제한 | `development_email_verification.dart` |
| 신체정보 라벨·입력·선택 오류 | `profile_form_page.dart` |
| 운동 목적·기간의 선택지 데이터 | `body_profile.dart`의 enum |
| 사진·글 카드와 입력창 | `onboarding_analysis_page.dart` |
| 단계 전환·로그아웃·초안 초기화 | `onboarding_view_model.dart` |
| 현재 화면 결정 | `onboarding_flow.dart` |
| 실제 저장 방식 | `local_onboarding_repository.dart` |
| 전체 색·팝업 스타일 | `app_colors.dart`, `app_theme.dart` |
| 공통 입력칸·고정 하단 버튼 | `design_reference_page.dart` |
| 사진 포맷·축소 | `image_picker_service.dart`, `image_preprocessor.dart` |

전체 선택 상태와 저장 동작을 바꿀 때는 Page와 ViewModel을 함께 확인한다. 라벨만 바꾼다고 저장값이나 검증 방식까지 바뀌지는 않는다.

## 13. 백엔드 연결 상태

현재는 로컬 미리보기다. 서버 회원가입·비밀번호 인증·JWT·이메일 발송·OAuth·사진 업로드·AI 결과 생성은 연결되어 있지 않다. 로컬 로그인은 저장된 이메일과 입력 형식만 확인하며, 비밀번호는 디스크에 저장하거나 저장된 비밀번호와 비교하지 않는다.

[onboarding_repository.dart](../lib/features/auth/data/onboarding_repository.dart)는 저장 작업에 필요한 메서드를 약속하는 인터페이스다. 현재는 `LocalOnboardingRepository`가 이 약속을 구현한다.

나중에 서버 저장소를 구현하면 `VitalityApp(onboardingRepository: 서버저장소)`로 전달할 수 있다. 이것이 의존성 주입이다. 기존 화면을 재사용하면서 저장 구현을 교체할 수 있지만, 실제 토큰 관리·API 오류 처리·메일/OAuth 연동도 별도로 구현해야 한다. `ApiContract`와 `AuthSession`은 그때 사용할 계약과 데이터 형식을 준비해 놓은 코드이며 HTTP 요청을 보내는 코드 자체는 아니다.

## 14. 테스트는 무엇을 확인하나?

| 테스트 파일 | 확인하는 내용 |
| --- | --- |
| `onboarding_view_model_test.dart` | 가입·저장·복원·실패 재시도·로그아웃 등 처리 |
| `onboarding_flow_test.dart` | 입력·화면 이동·항목별 오류·버튼 고정·화면 비교 |
| `development_email_verification_test.dart` | 인증번호 유효 시간·실패 횟수·재발급 |
| `api_contract_test.dart` | API 요청·응답 형식과 상태 분기 |
| `main_shell_test.dart` | 홈·분석·기록 탭 이동 |
| `image_preprocessor_test.dart` | 사진 크기 축소와 JPEG 변환 |
| `fake_onboarding_repository.dart` | 서버·기기 기능 대신 테스트에서 사용하는 가짜 저장소·사진 선택기 |

Golden 테스트는 화면을 이미지로 그려 기존 기준 이미지와 비교한다. 기준 이미지를 새로 만드는 것은 기존 디자인이 유지됐다는 검증과 다르다. 의도하지 않은 디자인 변경을 찾을 때는 기존 기준으로 `flutter test`를 실행한다.

```sh
flutter pub get   # 패키지 준비
flutter run       # 앱 실행
flutter analyze   # 잘못된 코드와 경고 확인
flutter test      # 기능·화면 자동 검사
```

## 15. 처음 읽을 때 추천 순서

1. `main.dart → bootstrap.dart → vitality_app.dart`: 앱의 시작점.
2. `onboarding_flow.dart`: 현재 화면이 어떻게 선택되는지.
3. `login_page.dart`, `signup_page.dart`: 화면에서 이벤트를 받는 방법.
4. `onboarding_view_model.dart`의 `submitAccount()`, `submitProfile()`, `_run()`: 처리 순서.
5. `onboarding_repository.dart → local_onboarding_repository.dart`: 저장 방법.
6. `BodyProfile`, `OnboardingProgress`: 저장하는 정보의 구조.
7. `profile_form_page.dart`, `onboarding_analysis_page.dart`: 입력 검사와 고정 버튼.
8. `test/app/onboarding_flow_test.dart`: 실제 사용 흐름을 코드로 확인.

모든 파일을 한 번에 외우기보다 ‘버튼 한 개를 눌렀을 때 어떤 메서드가 호출되는지’를 따라 읽으면 이해하기 쉽다.

## 16. 현재 Dart 파일 전체 찾아보기

| 파일 | 역할 |
| --- | --- |
| [app/bootstrap.dart](../lib/app/bootstrap.dart) | Flutter를 준비하고 앱을 실행. |
| [app/onboarding/onboarding_flow.dart](../lib/app/onboarding/onboarding_flow.dart) | 현재 상태에 따라 로그인·가입·홈 화면을 선택. |
| [app/onboarding/onboarding_view_model.dart](../lib/app/onboarding/onboarding_view_model.dart) | 입력값·진행 단계·저장·로그인·로그아웃을 관리. |
| [app/router/app_router.dart](../lib/app/router/app_router.dart) | 경로를 실제 화면에 연결. |
| [app/router/route_paths.dart](../lib/app/router/route_paths.dart) | 홈·로그인·가입·분석·기록 경로 이름. |
| [app/shell/app_bottom_nav.dart](../lib/app/shell/app_bottom_nav.dart) | 하단 탭의 아이콘·문구·선택 이벤트. |
| [app/shell/main_shell.dart](../lib/app/shell/main_shell.dart) | 홈·분석·기록 화면을 하단 탭으로 묶음. |
| [app/vitality_app.dart](../lib/app/vitality_app.dart) | 전체 테마·경로·개발용 구현을 구성. |
| [core/media/image_picker_service.dart](../lib/core/media/image_picker_service.dart) | 카메라/앨범 선택, 사진 파일 저장·복원·삭제. |
| [core/media/image_preprocessor.dart](../lib/core/media/image_preprocessor.dart) | 사진 방향 보정·축소·JPEG 변환. |
| [core/network/api_contract.dart](../lib/core/network/api_contract.dart) | 최종 API 경로·제한·오류 데이터 형식. |
| [core/validation/input_validators.dart](../lib/core/validation/input_validators.dart) | 닉네임·이메일·비밀번호·숫자 입력 검사. |
| [features/auth/data/development_email_verification.dart](../lib/features/auth/data/development_email_verification.dart) | 개발용 인증번호의 발급·만료·검사. |
| [features/auth/data/local_onboarding_repository.dart](../lib/features/auth/data/local_onboarding_repository.dart) | 가입 정보를 기기에 저장하는 개발용 구현. |
| [features/auth/data/models/auth_session.dart](../lib/features/auth/data/models/auth_session.dart) | 서버 로그인 응답·사용자 정보 데이터 형식. |
| [features/auth/data/models/onboarding_progress.dart](../lib/features/auth/data/models/onboarding_progress.dart) | 계정·신체정보·분석 입력·진행 상태. |
| [features/auth/data/models/signup_request.dart](../lib/features/auth/data/models/signup_request.dart) | 가입 요청에 필요한 입력과 동의 데이터. |
| [features/auth/data/onboarding_repository.dart](../lib/features/auth/data/onboarding_repository.dart) | 저장소가 구현해야 하는 작업 목록. |
| [features/auth/presentation/pages/consent_page.dart](../lib/features/auth/presentation/pages/consent_page.dart) | 기존 계정에서 부족한 필수 동의를 받음. |
| [features/auth/presentation/pages/login_page.dart](../lib/features/auth/presentation/pages/login_page.dart) | 로그인 입력과 회원가입 이동. |
| [features/auth/presentation/pages/signup_page.dart](../lib/features/auth/presentation/pages/signup_page.dart) | 가입 입력·인증번호 표시·필수 동의 창. |
| [features/auth/presentation/widgets/auth_support_actions.dart](../lib/features/auth/presentation/widgets/auth_support_actions.dart) | 소셜 버튼과 미연결 기능 안내. |
| [features/body_analysis/data/models/analysis_input.dart](../lib/features/body_analysis/data/models/analysis_input.dart) | 분석 방식·사진·글 입력 데이터. |
| [features/body_analysis/presentation/pages/analysis_entry_page.dart](../lib/features/body_analysis/presentation/pages/analysis_entry_page.dart) | 하단 분석 탭의 개발 준비 화면. |
| [features/body_analysis/presentation/pages/onboarding_analysis_page.dart](../lib/features/body_analysis/presentation/pages/onboarding_analysis_page.dart) | 가입 과정의 체형분석 입력 화면. |
| [features/home/presentation/pages/home_page.dart](../lib/features/home/presentation/pages/home_page.dart) | 저장된 설정 안내와 로그아웃. |
| [features/photos/data/models/selected_photo.dart](../lib/features/photos/data/models/selected_photo.dart) | 선택 사진 경로·크기와 사진 종류. |
| [features/photos/presentation/widgets/photo_input_field.dart](../lib/features/photos/presentation/widgets/photo_input_field.dart) | 사진 추가·미리보기·삭제 UI. |
| [features/profile/data/models/body_profile.dart](../lib/features/profile/data/models/body_profile.dart) | 신체정보와 선택 항목 enum. |
| [features/profile/presentation/pages/profile_form_page.dart](../lib/features/profile/presentation/pages/profile_form_page.dart) | 신체정보 입력·선택·오류 UI. |
| [features/workout/presentation/pages/workout_history_page.dart](../lib/features/workout/presentation/pages/workout_history_page.dart) | 하단 기록 탭의 개발 준비 화면. |
| [main.dart](../lib/main.dart) | 앱 실행의 첫 진입점. |
| [ui/core/theme/app_colors.dart](../lib/ui/core/theme/app_colors.dart) | 공통 색상 상수. |
| [ui/core/theme/app_spacing.dart](../lib/ui/core/theme/app_spacing.dart) | 공통 여백 크기. |
| [ui/core/theme/app_theme.dart](../lib/ui/core/theme/app_theme.dart) | 팝업·입력칸·체크박스 등 전체 테마. |
| [ui/core/theme/app_typography.dart](../lib/ui/core/theme/app_typography.dart) | 일반 공통 버튼의 글자 스타일. |
| [ui/core/widgets/app_scaffold.dart](../lib/ui/core/widgets/app_scaffold.dart) | 홈·분석·기록 등 일반 화면의 공통 틀. |
| [ui/core/widgets/design_reference_page.dart](../lib/ui/core/widgets/design_reference_page.dart) | 로그인·가입의 공통 화면·입력·버튼·폰트·고정 하단. |
| [ui/core/widgets/empty_view.dart](../lib/ui/core/widgets/empty_view.dart) | 아직 구현 전인 기능의 안내 UI. |
| [ui/core/widgets/primary_button.dart](../lib/ui/core/widgets/primary_button.dart) | 일반 화면과 동의 화면의 공통 버튼. |

현재 홈에 추가된 파일과 미리보기/서버 데이터 구분은 [홈 구현 기준](frontend-architecture/HOME.md)을 참고한다.

| 추가 파일 | 역할 |
| --- | --- |
| [home_preview_repository.dart](../lib/features/home/data/home_preview_repository.dart) | 기기 내 운동 미리보기 기록 저장·복원 |
| [home_view_model.dart](../lib/features/home/presentation/home_view_model.dart) | 홈의 날짜·예시 일정·운동 기록 집계 |
