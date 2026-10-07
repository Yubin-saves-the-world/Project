> 현재 API 기준은 [팀장 API 명세](../api-baseline/README.md)입니다. 이 문서의 이전 제안과 충돌하면 최신 기준을 따릅니다.

# Flutter 프론트 파일 구조 설계

작성일: 2026-10-06 · 대상: /Users/yubin/StudioProjects/FE · 상태: 구현 전 구조 제안

이 문서는 설계 시점 기록이다. 이후 실제 구조와 가입 3페이지를 적용했으며 현재 개발 상태는 [가입 구현 안내](ONBOARDING.md)와 루트 README를 따른다.

이 프로젝트는 기능별 폴더 안에 데이터 접근과 화면·화면 상태를 묶는 구조가 적합하다. 사진 분석의 대기·실패, 운동 세트 저장·복원, 홈의 여러 데이터 조합이 있어 화면 파일 안에 API 호출을 넣으면 상태가 서로 어긋나기 쉽다. 화면 → ViewModel → Repository → API/로컬 저장소 흐름으로 책임을 나눈다.

현재 pubspec.yaml에는 Flutter와 cupertino_icons만 있고 lib/main.dart는 간단한 시작 화면이다. 기존 상태 관리·라우터 규약은 없다. 이번 산출물은 폴더·파일·화면·API·상태의 설계이며 lib 파일과 패키지는 변경하지 않았다. 문서의 Dart 경로는 앞으로 만들 파일이다.

## 읽는 순서

1. [권장 폴더 구조와 파일 역할](01-file-structure.md)
2. [피그마 화면·기능·API 연결표](02-screen-api-map.md)
3. [상태 관리·데이터 흐름·구현 순서](03-state-and-work-plan.md)
4. [피그마에서 읽은 프레임·텍스트 목록](figma-inventory.json)

## 구조 요약

```text
lib/
├── main.dart
├── app/                 # 앱 시작, 라우터, 하단 탭, 기능 활성화
├── core/                # HTTP, 토큰 저장, 시간, 사진 선택 같은 기반 기능
├── ui/core/             # 공통 테마와 여러 기능에서 쓰는 기본 위젯
└── features/
    ├── auth/            # 가입·로그인·동의·세션
    ├── profile/         # 신체정보·설문
    ├── photos/          # 업로드·사진 관리
    ├── body_analysis/   # 체형 분석 요청·진행·결과·이력
    ├── goal_body/       # 목표 체형 등록·수정
    ├── exercises/       # 운동 종목 검색·상세
    ├── routines/        # 주간·오늘 루틴
    ├── workout/         # 종목 실행·세트·휴식·기록 조회
    ├── home/            # 홈에서 여러 기능의 결과를 조합
    ├── settings/        # 계정·동의·사진·프로필 설정 진입
    ├── ai_coach/        # 2차
    ├── diet/            # 2차
    ├── correction/      # 2차
    ├── community/       # 2차, 신고·차단 포함
    ├── marketplace/     # 확장
    ├── rewards/         # 확장, 미션·할인권
    └── notifications/   # 확장, 서버 푸시·기기 토큰
```

확장 기능 폴더는 개발 단계가 되었을 때 만든다. home과 settings는 다른 기능을 조합하는 화면이므로 불필요한 자체 API·Repository를 만들지 않는다. 관리자 API는 사용자 앱의 파일 구조에 포함하지 않는다.

## 확인한 자료와 기준

- 원본 기획서·ERD·기능 요구사항·API 목록, 이전 v1.1 보완안.
- [팀장 기능 요구사항](https://claude.ai/artifact/1PjEfi5Bk5k3W4wnRm3B6n), [팀장 API 명세](https://claude.ai/artifact/PDPy7sF21vktQt1RERPyYe).
- [v1.2 보완 제안](../team-revision-supplement/README.md).
- [피그마 캡스톤](https://www.figma.com/design/pdQ0Dn4jcL4m7FC0hXAQ7x/캡스톤?node-id=0-1): Page 1의 최상위 프레임 14개, 내용 있는 프레임 12개. 동일 신체정보의 두 안, 이름은 회원가입이지만 본문은 로그인인 프레임, 빈 프레임 2개를 구분했다. 등록된 COMPONENT/COMPONENT_SET은 확인되지 않았다. 화면 목록과 텍스트를 모두 읽고 홈·운동 실행 화면은 이미지로도 확인했다.

문서와 디자인이 충돌하면 화면의 모양은 피그마를 참고하고 기능 범위·요청 필드는 팀장 API를 따른다. v1.2의 필드·상태는 아직 팀 승인·서버 반영이 확인되지 않은 제안이다. 신규 필드가 있다고 가정해서 실제 서버와 연결하지 않는다. 결정이 필요한 충돌은 화면 매핑 문서에 표시했다.

## 추천 도구

| 역할 | 제안 | 적용 시점 |
| --- | --- | --- |
| 상태·의존성 주입 | flutter_riverpod의 Provider/Notifier/AsyncNotifier | 앱 기반 작업 |
| 화면 이동 | go_router | 앱 기반 작업 |
| HTTP·업로드·취소 | Dio | API 연결 |
| JWT 저장 | flutter_secure_storage | 로그인 연결 |
| 사진 촬영·앨범 | image_picker | 사진 입력 구현 |
| 요청·세트 식별자 | UUID 생성 도구 | 운동·AI 요청 구현 |
| 복원용 로컬 저장 | SQLite 기반 저장 어댑터 등 영속 저장소 | 미전송 세트 큐가 필요한 운동 단계 |

패키지 버전을 문서에서 고정하거나 설치하지 않았다. 설치할 때 현재 Dart/Flutter와 모바일 플랫폼 요구사항을 확인한다. 사진 리사이즈·EXIF 회전 처리, 시범 영상, 타이머 알림 패키지는 해당 단계에서 선택한다. 타이머 종료 알림과 서버의 알림 설정 기능은 서로 다른 책임이다.

화면·데이터 분리, Repository와 ViewModel 사용은 [Flutter 공식 구조 권고](https://docs.flutter.dev/app-architecture/recommendations)를 참고했다. 기능별 폴더 구성과 Riverpod 선택은 이 프로젝트에 맞춘 제안이다. [Riverpod Providers](https://riverpod.dev/docs/concepts2/providers), [go_router](https://pub.dev/packages/go_router), [Dio](https://pub.dev/packages/dio), [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage), [image_picker](https://pub.dev/packages/image_picker)의 공식 문서·패키지 설명을 확인했다.
