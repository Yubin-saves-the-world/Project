# 앱 아이콘 굵기

기준은 `assets/icons/home.svg`의 약 2px / 20px 비율이다. 홈과 프로필 SVG, 구글/카카오 브랜드 이미지는 원형을 유지한다.

앱의 Material 아이콘은 `AppIcon`을 사용한다. 고정 MaterialIcons 폰트에는 `weight` 축이 없어서 IconTheme.weight만 지정하면 실제 선이 바뀌지 않는다. 기존 SDK의 윤곽을 24px 벡터로 변환해 저장한 material_icon_paths.dart를 사용하고, 기존 약 2px 윤곽에 0.4px을 더해 홈의 비율에 가깝게 보정한다. 개별 아이콘의 모양·선택 상태·색·크기와 RTL/접근성 의미는 유지한다. 채워진 상태 아이콘은 채움을 유지하므로 모든 아이콘의 픽셀 면적이 같아지는 것은 아니다.

새 아이콘은 생성 스크립트로 윤곽 목록을 갱신한다. 생성 도구의 fonttools는 개발 도구로만 사용하며 앱 의존성이 아니다. 원본 Material Icons의 Apache-2.0 라이선스는 같은 폴더의 MaterialIcons_LICENSE.txt에 보관한다.

생성 명령: `python3 tools/icons/generate_icon_paths.py --flutter-root <Flutter SDK 경로>`. 실행 Python 환경에 fonttools가 필요하다. 생성 후 `dart format lib/ui/core/widgets/material_icon_paths.dart`를 실행한다.
