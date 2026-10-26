# 수정 코드 전달 (이메일 인증 · 비밀번호 찾기)

GitHub에 아직 올라가지 않은 앱 수정본입니다. 팀장이 푸시하면 이 폴더는 필요 없습니다.

| 파일 | 내용 |
|---|---|
| `fe_이메일인증_비밀번호찾기.patch` | 앱(FE)만의 변경 15개 파일. 원격 `main` 기준으로 충돌 없이 적용됨(`git apply --check`로 확인) |
| `server_auth_flow_test.dart` | 원격에서 코드 정렬을 새로 해서 패치로는 충돌하는 통합 테스트. 통째로 교체 후 `dart format` |

포함된 변경: 가입에 실제 이메일 인증(`email_verification_token`) 연결, 비밀번호 찾기를 인증번호 방식(`reset-request` → `reset-verification` → `reset`)으로 변경, 홈 카드의 잉크 경고 수정, 관련 테스트.
적용 방법은 `프론트_개발계획_팀원용.md`의 9-3을 보세요.
