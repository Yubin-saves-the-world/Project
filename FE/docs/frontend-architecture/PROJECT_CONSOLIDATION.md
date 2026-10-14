# 두 FE 폴더 비교 및 백업

정리 기준: `/Users/yubin/StudioProjects/Project/FE`. 기존 `/Users/yubin/StudioProjects/FE`는 삭제하지 않았습니다.

## 결과

- 홈 화면·ViewModel·기록 저장·새 운동 기록 달력은 두 폴더가 동일합니다.
- Git 연결 프로젝트는 실제 서버 Repository, 토큰 저장, 비밀번호 확인, 최신 API 오류 형식을 포함합니다. 기존 개발 폴더를 덮어쓰면 이 작업이 사라질 수 있으므로 서로 다른 앱 코드는 통합하지 않았습니다.
- 기존 폴더만의 동작: 앱 전체 한국어 locale, 체형 분석 입력 없이 홈으로 이동, 일부 폰트/타이틀 처리 및 사용하지 않는 폰트·아이콘 정리. 현재 프로젝트를 보존하기 위해 그대로 복사하지 않았습니다. 신체정보 숫자 너비 계산의 TextPainter 해제 차이도 백업에 보존했습니다.
- 기존 API 문서보다 Git 연결 프로젝트의 문서가 최신입니다. 오류 fields의 목록 형식과 예제가 추가되어 있으므로 기존 문서로 되돌리지 않았습니다.
- 보존한 예전 문서들은 기존 개발 폴더 기준의 참고 자료이며 현재 프로젝트의 확정 동작을 설명하는 문서가 아닙니다.

## 별도로 보존한 자료

- `docs/archive/standalone-fe-2026-10-14/CODE_GUIDE.md`
- `docs/archive/standalone-fe-2026-10-14/figma-reference/home/home.png`
- `docs/archive/standalone-fe-2026-10-14/frontend-architecture/HOME.md`
- `docs/archive/standalone-fe-2026-10-14/frontend-architecture/OPTIMIZATION.md`
- `tools/figma-design-export/bell.svg`
- `tools/figma-design-export/home.svg`

## 백업

- 경로: `/Users/yubin/StudioProjects/FE-backups/2026-10-14_120532`
- 압축파일: `standalone-FE.tar.gz`
- 보존: 소스, 테스트, assets, 문서, 도구, 네이티브 설정, 숨김 설정 파일.
- 제외: 재생성 가능한 build, .dart_tool, Pods, .symlinks, .gradle, 기타 패키지 캐시. 앱/시뮬레이터의 사용자 데이터는 프로젝트 폴더 밖에 있으므로 이 백업 대상이 아닙니다.
- manifest.json: 보관 파일별 SHA-256. comparison.json: 두 폴더 차이. SHA256SUMS.txt: 압축파일 해시.
- 압축을 다시 열어 285개 항목의 내용/링크를 원본과 대조했습니다.
- 복원: 원래 위치가 비어 있는 상태에서 `/Users/yubin/StudioProjects`에 압축을 풀면 FE 폴더가 복원됩니다. 백업 안의 README.md를 참고하세요.

## 아직 확인할 내용

실제 Project/FE 실행에서 로그인·가입·신체정보·체형분석·홈을 사용해 보세요. 서버 미연결 상태에서는 `flutter run --dart-define=USE_LOCAL_PREVIEW=true`로 로컬 미리보기를 사용할 수 있습니다. Project/FE는 현재 체형분석 입력 검증을 유지하므로 기존 개발 폴더의 무입력 건너뛰기와 동작이 다릅니다.

기존 폴더 삭제, Git 커밋·Push, 다른 팀원 코드 덮어쓰기를 실행하지 않았습니다.
