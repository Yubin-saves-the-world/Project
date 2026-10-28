# MOVID 앱 아이콘·시작 화면

- `assets/branding/movid-start.png`: Figma `846:2`의 `850:12` 이미지 원본. 사용자 제공 투명 로고와 SHA-256이 일치한다.
- `movid-app-icon.png`: 로고 전체 비율과 여백을 유지하고 순백색으로 합성한 1024px 앱 아이콘. iOS 아이콘에는 알파 채널을 남기지 않는다.
- `movid-wordmark.png`: 실제 Flutter `MovidWordmark`를 3배 해상도로 그린 네이티브용 글자 이미지. 디자인 스크린샷이 아니다.

글자 이미지 갱신은 `flutter test test/app/start_screen_test.dart --dart-define=GENERATE_NATIVE_BRANDING=true`로 수행한다. 이어서 sharp가 설치된 Node 환경에서 `node tools/branding/generate_assets.js`를 실행한다. 이 도구는 개발 시만 사용하고 앱 런타임 의존성을 추가하지 않는다.

iOS는 AppIcon 전체 슬롯과 LaunchImage/MOVIDWordmark를 사용한다. Android는 기존 런처 비트맵과 Android 8+ adaptive icon의 흰 배경/안전 영역 전경을 제공한다. Android 12+의 시스템 시작 화면은 OS가 아이콘 위치·마스크를 제어하므로 시스템용 규격을 따르며, Flutter 진입 후 시작 화면은 Figma 393×852 배치를 비율에 맞게 표시한다. 강제 지연이나 새로운 인증 분기를 추가하지 않고 기존 저장 정보 복원이 끝나면 기존 로그인/홈 분기로 이어진다.
