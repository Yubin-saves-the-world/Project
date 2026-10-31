# GitHub ZIP 실행 검증 — 2026-10-31

## 검증 대상

- 저장소: Yubin-saves-the-world/Project
- 브랜치: codex/ai-only-review-20261031
- 실제 다운로드한 실행 코드 커밋: 90d447a6589b1b4fe7fa288e77952e66c9787805
- 이 기록을 추가하는 후속 커밋은 문서만 변경합니다.
- 검증 환경: Apple Silicon Mac, Python 3.12.13. 다른 운영체제 실행은 미검증입니다.

## 실행 과정

GitHub 공식 ZIP을 다시 다운로드하고 파일이 해당 커밋과 일치하는지 확인했습니다. 경로에 공백을 포함한 새 폴더에 압축을 풀었습니다. .venv가 없는 상태에서 AI/run.sh --no-browser를 실행했습니다.

1. 다운로드 폴더의 AI/.venv를 새로 생성했습니다. 이전 실험 가상환경을 사용하지 않았습니다.
2. requirements와 고정 버전 제약으로 패키지를 실제 다운로드·설치했습니다. NumPy 1.26.4, OpenCV 4.11.0, torch 2.14.1을 확인했습니다. 중복 cv2 배포판 설치를 피하도록 opencv-contrib-python만 사용합니다.
3. 모델 소스를 별도로 지정하지 않고 기존 승인 계정의 Hugging Face 로그인을 사용했습니다. 공식 DINOv3 고정 리비전의 파일을 다운로드 폴더 AI/.cache/hub에 새로 받았습니다.
4. 모델 로딩 후 /health와 사진 테스트 페이지 /가 HTTP 200을 반환했습니다.
5. test1.jpg를 /v1/analyze에 보내 실제 MediaPipe·DINOv3 추론과 상완 특징 384차원 벡터를 확인했습니다.
6. 기존 /analyze/body의 실제 MediaPipe 실행과 camelCase 응답을 확인했습니다.
7. 손상 사진은 INVALID_IMAGE/422로 거절됐습니다.
8. 브라우저에서 같은 사진을 직접 선택하고 분석 버튼을 눌러 측정 완료·4개 수치·양쪽 상완 특징 추출 완료 표시를 확인했습니다.
9. 테스트 서버를 종료하고 8001 포트가 비어 있는 것을 확인했습니다.

단위·API·실행 준비 검사 17개도 통과했습니다. 개인 사진·모델·토큰·실제 사진 결과 스크린샷은 커밋하지 않았습니다. 검증 이미지와 환경은 로컬 런타임 경로에만 둡니다.

## 사용자가 실행하는 방법

[AI 브랜치 ZIP 다운로드](https://github.com/Yubin-saves-the-world/Project/archive/refs/heads/codex/ai-only-review-20261031.zip) → 압축 해제 → AI 폴더에서 bash run.sh 실행 → http://127.0.0.1:8001 접속.

Python 3.12와 승인된 Hugging Face 로그인이 필요합니다. 처음에는 라이브러리와 가중치를 내려받는 시간이 필요하며 첫 분석에서도 MediaPipe 모델을 추가로 받을 수 있습니다. main에 PR이 병합되기 전까지 기본 main ZIP은 이 실행 버전이 아닙니다.

이 검증은 AI 단독 서버와 AI/static의 사진 테스트 화면을 대상으로 합니다. Flutter 앱 전체나 BE 연동의 완료를 뜻하지 않습니다. 모든 코드·설정·문서 변경은 AI/ 하위뿐입니다.
