# settings

개발 단계: MVP

마이페이지에서 내 계정 정보·사진/AI 동의 관리·회원 탈퇴를 엽니다. 별도 하단 설정 탭은 추가하지 않습니다. 기존 신체정보·사진·목표 관리와 로그아웃을 유지합니다.

- `data/account_repository.dart`: 서버 내 정보 조회/수정/탈퇴.
- `data/account_data_cleaner.dart`: 해당 소유자의 기기 데이터만 정리.
- `data/consent_request_guard.dart`: 사진/AI 신규 쓰기 제한. 조회/삭제는 유지.
- `presentation/account_settings_view_model.dart`: 공유 계정 상태, 오류·재조회, 탈퇴 후 정리 재시도.
- `presentation/pages/account_settings_pages.dart`: 세 하위 화면.

정책과 레거시 정리 제한은 [계정 설정 연동 보고](../../../docs/project-context/ACCOUNT_SETTINGS_INTEGRATION.md)를 참고하세요.

구현 계획은 [프론트 파일 구조](../../../docs/frontend-architecture/01-file-structure.md)를 참고하세요.

- data: 계정 API와 동의·기기 정리 정책. 신체정보·목표·사진은 기존 기능 Repository를 사용합니다.
- presentation/pages: 화면.
- presentation/view_models: 화면 상태와 사용자 행동.
- presentation/widgets: 기능 전용 UI.
- `.gitkeep`은 비어 있는 폴더를 보존하는 파일이며 Dart 코드가 아닙니다.

