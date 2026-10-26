# 앱 개발 전달 자료 (2026-10-25)

| 파일 | 용도 |
|---|---|
| `프론트_개발계획_팀원용.md` | 먼저 읽기. MVP 범위, 작업 T0~T13, 결정 사항(D1~D4), 점검 결과 대응표 |
| `프론트_MVP_페이지별_작업명세.md` | 페이지별 API·필드·오류 코드 상세 |
| `FE_AGENTS.md` | 코덱스용 지시서. 앱 폴더에 `AGENTS.md`로 복사 |
| `수정코드/` | GitHub에 올라가지 않은 앱 수정본(패치). 적용법은 팀원용 문서 9-3 |
| `api/openapi.yaml` | 최신 서버 API 명세(원본). 팀 저장소의 `docs/final-specs`는 예전 버전일 수 있음 |
| `design/settings/` | 설정 화면 디자인(`settings_board.png`)과 전달용 스펙 |
| `design/password_reset/` | 비밀번호 찾기 디자인과 스펙 |

서버 주소: 개발 서버는 백엔드 담당이 켭니다. 앱은 `--dart-define=API_BASE_URL=...`로 지정합니다.
