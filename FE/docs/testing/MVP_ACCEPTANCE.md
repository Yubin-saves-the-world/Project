# MVP 검증 재실행

프로젝트 위치: `/Users/yubin/StudioProjects/Project/FE`.

## 프론트 자동 검증

```sh
cd /Users/yubin/StudioProjects/Project/FE
flutter analyze --no-pub
flutter test --no-pub
flutter test test/app/mvp_contract_flow_test.dart --no-pub
flutter devices
flutter test integration_test/native_smoke_test.dart --no-pub -d <시뮬레이터-ID>
flutter build ios --simulator --no-codesign
flutter build apk --release --no-pub
```

계약 테스트는 실제 ApiClient/Repository를 모의 HTTP에 연결한다. 네이티브 테스트는 사용자 토큰 대신 메모리 토큰, 고유 QA 계정 키와 테스트 폴더를 사용한다. 실제 회원/서버 자료를 수정하지 않는다. 테스트 후 일반 앱을 다시 실행하려면 `flutter run --no-pub --no-resident -d <시뮬레이터-ID>`를 사용한다.

## 실서버 테스트 선행 조건

백엔드 담당자가 테스트 전용 API 주소, 메일 인증번호 조회 helper 주소, AI/사진 처리 서비스의 준비 상태를 제공해야 한다. 현재 자동 메일 테스트는 `<MAIL_PEEK_URL>/last?to=<email>`에서 마지막 6자리 코드를 읽는다. 실제 사용자 계정을 사용하지 않는다.

```sh
LIVE_API_BASE_URL='http://<테스트-API>' LIVE_MAIL_PEEK_URL='http://<테스트-메일-helper>' flutter test test/live/server_live_test.dart

flutter test integration_test/server_auth_flow_test.dart -d <기기-ID>   --dart-define=API_BASE_URL='http://<테스트-API>'   --dart-define=MAIL_PEEK_URL='http://<테스트-메일-helper>'
```

일반 앱의 API는 컴파일 옵션 `--dart-define=API_BASE_URL=...`로 지정한다. iOS 시뮬레이터의 호스트 로컬 주소는 localhost를 사용할 수 있지만 Android 에뮬레이터의 호스트 주소는 보통 10.0.2.2다. 실제 휴대전화는 접근 가능한 서버 주소를 사용한다. 릴리스 빌드는 HTTPS 서버를 준비해야 하며 개발용 HTTP 허용을 릴리스 전체에 추가하지 않는다.

실서버 자동 인증 테스트 2개만으로 나머지 기능이 검증되지는 않는다. 이후 아래 흐름을 새 테스트 계정으로 수행한다.

## 실제 서버·기기에서 남은 확인

- [ ] 발송된 실제 코드로 가입, 틀린/만료/재발송·중복 이메일/닉네임, 로그아웃·재실행·비밀번호 재설정.
- [ ] 신체정보 저장/수정, 사진 촬영·앨범 권한·회전·용량/개수·삭제 및 실제 파일 처리.
- [ ] 정면 필수/측면 선택 분석, pending/done/failed, null 측정값, 분석 횟수 제한, 앱 종료 후 이어보기.
- [ ] 목표 설명/사진·처리 중 수정 충돌/삭제 제한, 실제 루틴 생성·주간 휴식일·상세.
- [ ] 수동 일정 유지/추천 선택·휴식일 복원, 홈/달력/기록의 집계 일치.
- [ ] 종목 시작/이어하기, 세트 저장 응답 유실과 동일 UUID 재전송, 버전 충돌, 휴식/경과 시간, 6시간 중단.
- [ ] 종료 메모/요약·다음 종목·루틴 완료·홈 탭 복귀, 기록 세트 수정/삭제 후 서버 루틴/통계 재계산.
- [ ] 사진/AI 동의 철회 확인·처리 중 AI 취소·신규 요청 차단·기존 조회·재동의, current/goal 사진 삭제의 skipped 처리.
- [ ] 탈퇴 확인·서버 사진/개인정보 삭제·즉시 권한 차단·해당 계정 기기 정리·동일 이메일 재가입.
- [ ] iOS 실물 기기·Android 런타임·느린 네트워크/오프라인·강제 종료/복원.
- [ ] 소유 정보 없는 레거시 공용 사진/익명 데이터의 운영 정리 정책. 다른 계정 자료를 일괄 삭제하지 않는다.
- [ ] 실제 배포 시 서버 주소/TLS·정식 앱 ID/서명·스토어 준비 상태. 현재 Android release는 기존 debug 서명 설정이다.

현재 실행 결과와 범위는 [T13 검증 보고](../project-context/MVP_FLOW_VERIFICATION.md)를 확인한다. 미실행 항목을 통과로 표시하지 않는다.
