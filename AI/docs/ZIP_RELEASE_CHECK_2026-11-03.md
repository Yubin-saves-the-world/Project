# GitHub ZIP 독립 검증 결과

PR: https://github.com/Yubin-saves-the-world/Project/pull/23
검증 코드 기준: 2bb305b (이후 검증 기록 문서만 추가).

## 실제 실행

- GitHub codeload에서 게시된 작업 브랜치 ZIP을 새 폴더로 다운로드했다.
- ZIP의 AI 폴더에 기존 작업 환경과 다른 Python 3.12 가상환경을 생성했다.
- ZIP에 선언된 requirements-test.txt와 requirements-dev.txt로 의존성을 설치했다.
- ZIP 소스에서 자동 테스트 **152개 통과**.
- ZIP 소스·새 환경에서 FastAPI 서버 기동 성공.
- 실제 정면 사진 분석 HTTP 200 및 DINOv3 특징 블록 확인. 약 3.47초.
- 실제 Spring 로그인으로 인증된 호환 서버의 Qwen3 대화 생성, SQLite 저장·조회·삭제 성공.
- 시험 서버는 검증 후 종료했다.

## 재사용한 외부 준비물

이 컴퓨터의 승인된 DINOv3 가중치, 공식 포즈 자산, 기존 로컬 Ollama qwen3:4b, 실행 중인 로컬 인증 BE를 재사용했다. 해당 자산은 GitHub ZIP에 포함되지 않는다. 다른 컴퓨터의 최초 모델 다운로드·승인·계정·설정을 대신 완료한 검사가 아니다.

이력 저장은 **AI 호환 서버 SQLite**다. 실제 BE의 MySQL 코치 분기를 Qwen3로 바꾼 것이 아니다. 원본 Flutter 코치 화면도 현재 준비 중이므로 종단 UI 성공으로 주장하지 않는다.

## 현재 가능한 재실행

프로젝트 루트에서:

```bash
bash AI/run-coach.sh
# 승인·모델이 없는 환경에서 사진 측정과 코치만 사용할 경우
# bash AI/run-coach.sh --geometry-only
```

Ollama 실행·qwen3:4b 준비가 필요하다. 첫 실행은 의존성·자산 다운로드 시간이 걸린다. 실행 포트가 이미 사용 중이면 기존 서버를 확인하거나 --port를 지정한다.

호환 서버의 인증·사진·코치 API를 함께 사용하려면 `bash AI/run-flutter.sh --no-app`을 사용한다. 원본 Flutter 코치 화면 연결은 FE 담당 작업으로 남는다.

## 범위

원본 FE·BE 파일은 변경하지 않았다. GitHub PR의 변경 경로도 모두 AI/로 확인했다. 사진·모델·DB·토큰·가상환경·실제 대화 응답은 커밋하지 않았다. 실제 검사 로그·응답은 비공개 AI/.runtime/release_20261103 및 coach_bridge_verification에 보관했다.
