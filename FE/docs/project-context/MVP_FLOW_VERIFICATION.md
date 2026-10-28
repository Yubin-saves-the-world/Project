# MVP 전체 흐름 점검 (T13)

2026-10-27 · 실제 작업 대상 `/Users/yubin/StudioProjects/Project/FE`.

T12는 `e321fe9` (`feat: 마이페이지 계정 및 동의 관리 구현`)로 origin/main에 커밋·Push했다. 아래 T13 변경은 아직 커밋·Push하지 않았다.

## 결론과 검증 범위

**프론트 계약·화면·네이티브 저장소 점검은 통과했다. 실제 백엔드/메일/AI와 연결한 최종 인수 테스트는 미완료다.**

- `LIVE_API_BASE_URL`, `LIVE_MAIL_PEEK_URL`, `API_BASE_URL`, `MAIL_PEEK_URL`은 현재 셸에 설정되어 있지 않았다.
- 기본 로컬 `localhost:8080`과 테스트 메일 `localhost:18025`는 연결되지 않았다. 백엔드·메일 서비스를 임의로 실행하거나 BE를 변경하지 않았다.
- 테스트 전용 HTTP 계약 서버와 독립 QA 소유 키를 사용했다. 기존 사용자 토큰을 읽어 실서버 요청에 사용하지 않았고 실제 회원 데이터에 수정·탈퇴를 실행하지 않았다.

## 발견하여 수정한 문제

### Android 릴리스의 인터넷 권한 누락

개발용 manifest에는 INTERNET이 있었지만 main manifest에는 없어 릴리스 앱에서 서버 통신이 막힐 수 있었다. `android/app/src/main/AndroidManifest.xml`에 권한을 추가했다. 최종 릴리스 APK 빌드와 병합된 release manifest의 INTERNET 포함을 확인했다. 릴리스의 전체 HTTP 허용 같은 네트워크 완화 설정은 추가하지 않았다.

### 소유가 확인된 레거시 사진의 정리 순서

이전 탈퇴 정리는 소유가 일치하는 로컬 가입 JSON을 먼저 지워 그 안에만 남은 옛 사진 경로를 잃을 수 있었다. 이제 그 JSON에서 소유자와 정면/측면/목표 사진 경로를 확인하고, 중복 경로를 한 번씩 정리한 뒤 JSON을 지운다. 파일 정리에 실패하면 경로/소유 정보를 유지해 기기 정리를 다시 시도할 수 있다.

실제 삭제는 기존 PhotoPicker.discard를 사용하므로 앱이 만든 사본만 대상으로 한다. 갤러리 원본은 지우지 않는다. 다른 계정·소유 불명 자료는 정리하지 않는다. 소유 정보가 전혀 없는 옛 공용 파일을 임의 일괄 삭제하지 않는 T12 정책은 유지한다.

## 연결 시나리오

`test/app/mvp_contract_flow_test.dart`는 하나의 상태 유지 HTTP 픽스처에 실제 ApiClient·서버 Repository·ViewModel들을 연결한다.

1. 인증번호 발송·잘못된 코드·정상 코드 → verification token → 가입·로그인.
2. 신체정보 저장 → 같은 세션으로 앱 상태 복원.
3. 설명 목표 → 정면 사진 업로드 → 분석 결과(측정값 null 유지) → 명시적 루틴 생성.
4. 종목 조회 → 주간 루틴 → 홈 추천 선택/집계.
5. 종목 시작 → 세트 저장 응답 유실 → 앱 상태 재생성 → 중복 없이 복원 → 추가 세트 → 종료 요약/루틴 완료.
6. 홈/기록 합계 → 완료 세트 수정과 서버 재계산 → 로그 삭제와 루틴 상태/달력/홈 갱신.
7. 닉네임 변경 → AI 철회 중 조회 허용·새 생성 차단 → 재동의 → 로그아웃·로그인 → 탈퇴·세션 정리.

이 픽스처는 API 형식과 연결을 검사하는 테스트 코드다. 실제 메일 발송·AI 분석·통신 장애·서버 데이터베이스 구현을 검증한 것으로 해석하면 안 된다.

## iOS 네이티브 검증

iPhone 16 Pro, iOS 18.3 시뮬레이터에서 `integration_test/native_smoke_test.dart`의 **3개 테스트 통과**.

- 개발용 가입 UI → 동의 → 신체정보 3단계 → 홈 → 기존 달력 → 마이페이지 → 로그아웃.
- 실제 SharedPreferencesAsync와 앱 파일 시스템에서 테스트 계정 기록·사진 사본만 정리하고 다른 테스트 계정 자료 보존. 실제 FilePhotoPreparer/compute로 JPEG 처리.
- 계약 HTTP를 주입한 실제 앱에서 분석 입력/결과 → 루틴 생성/상세 → 운동 세트/메모/종료 → 홈 복귀 → 기록 상세/세트 수정 → 계정 닉네임 변경 → 탈퇴 확인 → 로그인 복귀.

마지막 시나리오는 이미 가입·신체정보가 있는 HTTP 픽스처로 시작한다. 신규 가입 UI는 첫 테스트, 신규 가입부터의 실제 Repository 연결은 위 계약 시나리오가 검증한다. 모든 단계를 실제 서버에서 새 계정 하나로 진행한 검증은 아니다.

테스트마다 고유 QA 소유 키/임시 폴더를 사용하고 종료 시 그 자료만 제거한다. 전역 preferences 전체 삭제는 사용하지 않는다. 테스트 후 일반 main.dart 앱을 시뮬레이터에 다시 빌드·실행했다. 기본 API가 꺼져 있으므로 일반 앱의 실서버 로그인 성공은 보장하지 않는다.

## 빌드·회귀 결과

Flutter 3.41.6 / Dart 3.11.4, 2026-10-27.

| 항목 | 결과 |
|---|---|
| flutter analyze --no-pub | 문제 없음 |
| flutter test --no-pub | **302개 통과, 실서버 2개 미실행** |
| iOS 네이티브 통합 테스트 | **3개 통과** |
| iOS 시뮬레이터 앱 빌드 | 성공 |
| 최종 Android release APK 빌드 | 성공, 71.6MB |
| Android release 병합 manifest | INTERNET 포함 |
| 일반 iOS 앱 재실행 | main.dart 빌드·실행 성공 |
| 기존 골든 | 변경 없음 |

APK 위치는 `build/app/outputs/flutter-apk/app-release.apk`다. 빌드 산출물은 Git에 넣지 않는다. 현재 Android release 서명은 기존 프로젝트의 debug 키 설정을 그대로 사용하므로 스토어 배포용 서명 완료를 의미하지 않는다. Android 런타임/실제 단말 테스트와 iOS 실물 기기·실제 카메라 권한 검증은 하지 않았다.

## 변경 파일

앱:

- `android/app/src/main/AndroidManifest.xml`: 릴리스 인터넷 권한.
- `lib/features/settings/data/account_data_cleaner.dart`: 확인된 옛 사진 경로의 선행 정리·재시도 보존.
- `lib/app/onboarding/onboarding_flow.dart`: 앱 사본 삭제 콜백 연결.

테스트:

- `test/fakes/mvp_contract_server.dart`: 상태 유지 HTTP 계약 픽스처.
- `test/app/mvp_contract_flow_test.dart`: 가입부터 탈퇴까지 실제 저장소/상태 관리 연결.
- `test/features/settings/legacy_photo_cleanup_test.dart`: 정리 순서·중복 제거·실패 재시도·다른 계정 보존 3개.
- `integration_test/native_smoke_test.dart`: 네이티브 화면/기기 저장소/계약 HTTP UI 흐름.

문서:

- 현재 보고서.
- `docs/testing/MVP_ACCEPTANCE.md`: 재실행 명령과 실서버 확인 항목.
- `docs/project-context/README.md`, `ACCOUNT_SETTINGS_INTEGRATION.md`: 최신 상태와 후속 정리 검증 기록.

BE·의존성·Figma·기존 UI 디자인은 변경하지 않았다. 기존 미추적 실패 진단 이미지는 이번 작업과 커밋에 포함하지 않는다.

## 남은 인수 조건

테스트 전용 실제 API/메일 조회 주소가 제공되면 실제 신규 계정으로 메일 인증부터 분석/추천/운동/기록/설정까지 한 바퀴를 실행해야 한다. SMTP/AI/사진 저장소의 실제 동작, 네트워크 끊김·프로세스 강제 종료 복원, 서버의 권한/통계/루틴 재계산을 확인해야 한다. 자세한 항목과 실행 방법은 인수 체크리스트를 따른다.

현재 결과를 운영 배포 준비 완료나 실서버 T13 최종 인수 완료로 표시하지 않는다. 독립적으로 진행 가능한 다음 기능은 사용자가 추가한 커뮤니티다. 인공지능 코치 등의 준비 중 화면은 이번 점검에서 임의 구현하지 않았다.
