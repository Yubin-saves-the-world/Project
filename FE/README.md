# Project Vitality Flutter 프론트

팀장 API 명세를 데이터·동작 기준으로, 피그마를 화면 디자인 기준으로 사용하는 Flutter 프론트입니다. [최종 기능·API·ERD 기준](docs/final-specs/README.md)를 먼저 확인하세요.

## 현재 연결된 구조

`main.dart → app/bootstrap.dart → VitalityApp → AppRouter → MainShell → 기능별 Page`

- app: 앱 시작·라우터·하단 탭·설정 위치.
- core: 네트워크·저장소·시간·사진 처리 위치.
- ui/core: 피그마 색상 기반 테마·공통 화면과 빈 상태 위젯.
- features: 기능별 데이터·화면·상태·전용 UI.
- assets: 아이콘·이미지·폰트 위치. 실제 리소스 추가 후 pubspec.yaml에 등록합니다.
- dev/fixtures: 개발용 가짜 API 데이터 위치.
- test: 앱 탐색 및 기능별 검증 위치.

첫 실행은 로그인 화면입니다. 회원가입 → 신체정보 → 체형 분석 입력의 3페이지로 이동하며 로그인과 가입을 오갈 수 있습니다. 입력 검증·사진 선택·로컬 저장·재실행 복원·완료 후 홈 진입을 구현했습니다. 가입 동의 4개와 성별(남성·여성) 선택은 필수이며 신체정보 저장 시 온보딩이 완료됩니다. 로그아웃은 계정·기록을 유지하고 로그인 화면으로 이동합니다. 개발용 로그인은 비밀번호 인증 없이 화면 흐름만 확인합니다. 백엔드와 AI는 아직 연결하지 않았으며 실제 계정·분석 결과를 생성하지 않습니다. 홈·분석·기록 탭의 나머지 업무 기능은 개발용 기본 화면입니다. 2차·확장 폴더는 위치만 예약했습니다.

## 실행·검증

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

기본 Flutter 라우터와 ChangeNotifier로 가입 흐름을 연결했습니다. image_picker·image·path_provider·shared_preferences·flutter_svg를 사용합니다. 네 인증·가입 화면은 현재 Figma의 Pretendard 서체·색상·SVG·배치를 반영했습니다. 실제 인증·API 상태 관리 단계에서 설계한 Riverpod·go_router·Dio 등을 도입할 수 있습니다.

## 설계 자료

- [가입 3페이지 구현과 백엔드 연결 지점](docs/frontend-architecture/ONBOARDING.md)

- [파일 구조](docs/frontend-architecture/01-file-structure.md)
- [피그마 화면·API 연결표](docs/frontend-architecture/02-screen-api-map.md)
- [상태 관리와 작업 순서](docs/frontend-architecture/03-state-and-work-plan.md)
- [팀장 수정본 보완안](docs/team-revision-supplement/README.md)

현재 Figma 구현과 개발용 인증번호(`123456`), 운동 횟수 상한값 매핑은 [가입 구현 기준](docs/frontend-architecture/ONBOARDING.md)을 참고하세요.
