# 프로젝트 정리·최적화 결과

현재 로그인·회원가입·신체정보·체형분석 UI와 동작을 유지하는 범위로 정리했다. 정리 전·후 모두 동일한 기존 golden 이미지로 화면 비교 테스트를 실행했고 기준 이미지를 새로 생성하지 않았다.

## 분석과 정리

- 앱 진입점과 테스트의 import 그래프를 함께 검사했다. `OnboardingFrame`, `AppTextField`, `ChoiceChipGroup`, `AppRadii` 4개는 호출되지 않아 삭제했다. 현재 남은 Dart 40개 파일은 모두 앱 또는 테스트에서 사용한다.
- 예전의 비밀번호 확인용 상태, 사용하지 않는 목표 설명 setter·제목 폭 매개변수·테마 상수를 제거했다. 실제 가입 검증과 저장 데이터 형식은 유지했다.
- Noto Sans KR·Inter 및 사용하지 않는 Pretendard 가변 원본을 삭제했다. 실제 쓰는 CapstoneUI Regular·Medium 파일과 Pretendard OFL은 유지했고 활성 폰트의 바이트도 동일함을 확인했다.
- 사용하지 않는 SVG와 동일한 아이콘 사본 18개를 삭제했다. 세 페이지의 뒤로 아이콘과 로그인·가입의 소셜 로고를 바이트가 동일한 파일로 공유한다. 사용 에셋은 SVG 6개·PNG 2개다. `pubspec.yaml`에 파일별로 등록해 도구가 추가 원본을 추출해도 자동으로 앱에 포함되지 않는다.
- `CupertinoIcons`를 사용하지 않아 `cupertino_icons` 의존성을 제거했다. 나머지 패키지는 유지했고 버전 업그레이드는 하지 않았다.
- 글자 폭 계산용 `TextPainter`를 사용 후 해제하고 중복 색상 정의를 공통 테마 상수로 통합했다.
- 이전 테스트 실패 진단 이미지 4개를 지우고 앞으로 생성되는 진단 폴더를 ignore했다. 사용 중인 golden 이미지·기획/최종 API 문서·재사용 가능한 Figma 추출 도구는 유지했다.
- `AuthSession`은 현재 서버와 연결되지는 않았지만 최종 API 계약 검증 테스트에서 사용하므로 유지했다. 계정·신체정보·사진의 기기 저장 형식과 사용자 데이터는 변경하지 않았다.

## 크기 변화

| 대상 | 정리 전 | 정리 후 | 감소 |
| --- | ---: | ---: | ---: |
| 프로젝트 assets | 23.99 MiB | 5.98 MiB | 18.01 MiB |
| iOS 빌드의 사용자 assets | 17.55 MiB | 5.97 MiB | 11.58 MiB |

위 값은 에셋의 실제 파일 바이트 합계다. 엔진·Dart 코드·OS별 압축이 포함된 전체 앱 설치 용량이나 실행 속도 측정값은 아니다.

## 검증

- 정리 전 테스트 51개 통과.
- 정리 후 `flutter analyze`: 오류·경고 없음.
- 정리 후 테스트 51개 통과. 기존 네 화면·추가 창 golden 비교, 작은 화면·큰 글꼴·키보드, 입력·동의·로그인·로그아웃·복원·사진 처리 포함.
- iOS 시뮬레이터 빌드 성공. 빌드된 FontManifest와 아이콘 파일 목록도 확인했다.
- 정리 전 소스·에셋·설정 백업: `/private/tmp/fe-cleanup-before.tar.gz`.

## 삭제 파일

- `lib/app/onboarding/widgets/onboarding_frame.dart`
- `lib/ui/core/widgets/app_text_field.dart`
- `lib/ui/core/widgets/choice_chip_group.dart`
- `lib/ui/core/theme/app_radii.dart`
- `assets/icons/figma/figma-655_777.svg`
- `assets/icons/figma/figma-655_776.svg`
- `assets/icons/figma/figma-640_547.svg`
- `assets/icons/figma/figma-655_770.svg`
- `assets/icons/figma/figma-640_543.svg`
- `assets/icons/figma/figma-681_33.png`
- `assets/icons/figma/figma-681_41.svg`
- `assets/icons/figma/figma-681_41.png`
- `assets/icons/figma/figma-681_33.svg`
- `assets/icons/figma/figma-647_758.svg`
- `assets/icons/figma/figma-681_31.svg`
- `assets/icons/figma/figma-647_750.svg`
- `assets/icons/figma/figma-681_39.svg`
- `assets/icons/figma/figma-655_782.svg`
- `assets/icons/figma/figma-655_769.svg`
- `assets/icons/figma/figma-655_783.svg`
- `assets/icons/figma/figma-655_778.svg`
- `assets/icons/figma/figma-655_784.svg`
- `assets/fonts/NotoSansKR.ttf`
- `assets/fonts/NotoSansKR-OFL.txt`
- `assets/fonts/Inter.ttf`
- `assets/fonts/Inter-OFL.txt`
- `assets/fonts/PretendardVariable.ttf`
- `test/app/failures/profile_testImage.png`
- `test/app/failures/profile_masterImage.png`
- `test/app/failures/profile_isolatedDiff.png`
- `test/app/failures/profile_maskedDiff.png`
