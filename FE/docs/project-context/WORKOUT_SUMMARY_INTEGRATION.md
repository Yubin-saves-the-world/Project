# 운동 종료 요약 연동 (T10)

2026-10-27 · `/Users/yubin/StudioProjects/Project/FE`.

이전 T9는 `8b4b0b3` (`feat: 운동 진행 및 세트 기록 복원 구현`)으로 커밋·Push했다. 아래 T10 변경은 아직 커밋·Push하지 않았다.

## 구현 흐름

1. 진행 화면의 **종목 종료**에서 선택 메모를 입력한다. 메모는 최대 255자이며 빈 메모로도 종료할 수 있다. 시트를 취소하면 종료 요청을 보내지 않는다.
2. `PATCH /api/workout-logs/{id}/complete`에 메모를 전달한다. `duration_sec`는 생략해 서버가 실제 경과 시간을 확정하도록 한다. 요청 전 메모를 기존 계정·로그별 복원 저장소에 보관한다.
3. 성공하면 운동 진행 화면을 종료 요약 화면으로 교체한다. 뒤로가기만으로 이미 종료한 운동을 다시 편집하는 화면이 나타나지 않는다.
4. 서버가 확정한 운동 시간·총 볼륨·완료 세트 수와 메모를 표시한다. 루틴 운동은 완료 종목 수/전체 종목 수도 보여 준다. 마지막 종목이면 루틴 완료를 표시하며 지난 날짜 루틴을 오늘 루틴으로 표시하지 않는다.
5. 남은 오늘의 예정 루틴 종목이 있으면 **다음 종목**을 제공한다. 버튼을 누를 때 루틴을 다시 조회하고, 현재 종목과 완료 종목을 제외한 첫 미완료 종목을 고른다. 루틴 ID·목표 세트/횟수/무게·휴식 시간을 전달해 T9 화면으로 교체한다. 요약을 여는 것만으로 다음 운동을 자동 시작하지 않는다.
6. **홈으로**는 화면 경로를 첫 화면까지 정리하면서 실제 홈 탭을 선택하고 홈 데이터를 갱신한다. 분석 탭이나 마이페이지에서 시작했어도 홈으로 복귀한다.

빈 운동 종료/명시적 운동 취소는 T9의 확인 후 로그 삭제를 유지하며 완료 요약을 임의 생성하지 않는다. 기존 로컬 운동 미리보기와 수동 일정은 그대로 유지한다.

## 오류·복원

- 완료 API의 시간·볼륨·세트 수를 사용한다. 프론트 타이머나 입력 세트 합으로 서버 확정 결과를 대체하지 않는다.
- 종료 응답이 유실되면 진행 화면에서 **서버 기록 다시 확인**으로 실제 상세를 조회한다. 이미 completed인 기록은 서버 상세의 종료 시각·시간·볼륨·세트 수·메모로 요약을 복구한다. 앱 상태를 새로 만들어도 동일하며 종료 PATCH를 자동 반복하지 않는다.
- 루틴의 최신 상태를 조회하지 못해도 완료된 운동 요약은 유지한다. 다음 종목을 시작하지 않고 루틴 재조회와 홈 복귀를 제공한다. 재조회로 완료/건너뜀/날짜 변경을 확인하면 다음 종목을 잘못 시작하지 않는다.
- 중복 종료/다음 종목 탭은 기존 상태 관리와 화면의 작업 중 가드로 차단한다. 요약 화면 전환도 중복되지 않게 보호한다.
- 기존 공통 API의 인증 만료 처리를 유지한다. BE 계약이나 저장 형식은 변경하지 않았다.

## 화면

기존 관리 화면의 흰색 배경, 파란색, 폰트, 카드·입력 양식을 사용한다. 주요 버튼은 안전 영역 안의 하단 영역에 두고 요약/메모는 스크롤한다. 오류가 생겨도 버튼이 본문 아래로 밀리지 않는다. Figma 파일과 기존 로그인/분석/홈 디자인은 수정하지 않았다.

393×852 및 320×640/130% 글꼴에서 다음 종목/루틴 완료 화면과 메모 시트를 확인했다. 작은 화면에서 메모 등 본문 일부는 스크롤해서 볼 수 있다.

## 변경 파일

새 코드:

- `lib/features/workout/data/workout_completion.dart`: 서버 확정 종료 결과 모델 및 상세 복원.
- `lib/features/workout/presentation/workout_summary_view_model.dart`: 최신 루틴 조회, 진행률과 다음 종목 선택.
- `lib/features/workout/presentation/pages/workout_summary_page.dart`: 종료 요약, 메모 표시, 다음 종목/홈 이동.

기존 코드:

- `lib/features/workout/data/workout_repository.dart`: 메모 전송 및 상세 종료 필드 읽기.
- `lib/features/workout/presentation/workout_view_model.dart`: 종료 메모 검증·보관, 확정 결과 해석과 복원.
- `lib/features/workout/presentation/pages/workout_page.dart`: 메모 입력 시트·요약 전환·복구 연결.
- `lib/features/workout/presentation/workout_dependencies.dart`: 홈 이동 콜백.
- `lib/app/onboarding/onboarding_flow.dart`, `lib/app/shell/main_shell.dart`: 홈 탭 복귀 요청을 연결하고 리스너를 정리한다.

테스트/문서:

- `test/fakes/fake_workout_repository.dart`, `test/features/workout/workout_repository_test.dart`.
- `test/features/workout/workout_summary_test.dart`, `workout_summary_page_test.dart`.
- `docs/project-context/previews/workout-summary-{next,done}-{1.0,1.3}.png`, `workout-finish-memo.png`.
- 현재 보고서·프로젝트 인수인계·workout README.

## 검증과 다음 단계

2026-10-27 · Flutter 3.41.6 / Dart 3.11.4.

- `flutter analyze --no-pub`: 문제 없음.
- `flutter test --no-pub`: **261개 통과, 실서버 2개 환경 미지정으로 미실행**.
- 신규 14개 테스트는 서버 확정 값, 메모/길이/중복 종료, 종료 응답 손실과 앱 상태 재생성, 최신 루틴 재조회와 다음 종목 제한, 자유 운동, 오류 재시도, 화면 2개 크기/글꼴, 메모 저장→요약→다음 종목, 홈 탭 복귀를 포함한다. 기존 운동 API 테스트에도 메모 전달/시간 생략 검증을 추가했다.
- `git diff --check` 통과. 기존 골든·BE·패키지 의존성은 변경하지 않았다. 기존 테스트 실패 이미지들은 이 커밋과 이번 변경에 포함하지 않는다.

실제 서버/실기기에서 종료/앱 재실행을 확인한 결과는 아니며 가짜 서버/저장소와 위젯 테스트로 검증했다. 다음은 T11의 운동 기록 달력·목록·상세·수정·삭제 연동이다. 현재 홈 달력의 서버 날짜별 기록 조회와 기존 기기 기록은 유지된다.
