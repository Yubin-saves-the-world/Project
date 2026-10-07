# settings

개발 단계: MVP

각 기능의 설정 진입 화면입니다. 프로필·목표·동의 변경은 해당 기능 Repository를 사용합니다.

구현 계획은 [프론트 파일 구조](../../../docs/frontend-architecture/01-file-structure.md)를 참고하세요.

- data: 모델·API·Repository. home/settings는 조합 화면이라 별도 데이터 계층을 만들지 않습니다.
- presentation/pages: 화면.
- presentation/view_models: 화면 상태와 사용자 행동.
- presentation/widgets: 기능 전용 UI.
- `.gitkeep`은 비어 있는 폴더를 보존하는 파일이며 Dart 코드가 아닙니다.

