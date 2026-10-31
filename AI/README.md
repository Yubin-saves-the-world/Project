# MOVID AI 서버

**확정 작업 범위는 `AI/` 폴더뿐입니다.** FE·BE·루트 문서·공통 설정을 변경하지 않습니다. AI 문서, 테스트, 설정도 이 폴더 안에서 관리합니다. [작업 지침](AGENTS.md)을 따릅니다.

## 검수한 상완 크롭의 실험용 윤곽 분류

`POST /v1/contour/classify`와 `/contour-test` 화면을 추가했습니다. 피부가 보이는 상완 크롭을 사람이 확인한 경우에만 실험 모델의 참고 후보·모델 점수·보류 상태를 반환합니다. 근육량이나 체형 점수가 아닙니다. 학습 모델을 명시적으로 설정해야 하며 사진·학습 결과는 Git에 포함하지 않습니다. [초기 실험과 실행 방법](docs/CURRENT_EXPERIMENT.md)을 확인하세요.

## 원본 Flutter 앱에서 테스트하기

프로젝트 루트에서 `bash AI/run-flutter.sh --photo "/사진/test1.jpg"`를 실행합니다. 원본 FE·BE 코드는 수정하지 않고 AI 실행 폴더의 복사본으로 로그인·사진 선택·실제 AI 분석을 연결합니다. [준비 환경·실행 순서·현재 한계](docs/FLUTTER_LOCAL_DEMO.md)를 먼저 확인하세요. 아래 `run.sh` 경로는 AI 단독 웹 테스트입니다.

## GitHub ZIP으로 바로 시작하기 (macOS)

최신 AI 코드가 있는 [기본 main ZIP](https://github.com/Yubin-saves-the-world/Project/archive/refs/heads/main.zip)을 다운로드하고 압축을 풉니다. PR #7은 main에 병합됐습니다. 기본 main ZIP에 AI 서버가 포함됩니다.

1. Python 3.12를 설치합니다. 이 컴퓨터에 이미 설치돼 있다면 그대로 사용합니다.
2. 압축을 푼 프로젝트의 `AI` 폴더에서 터미널로 `bash run.sh`를 실행합니다. macOS에서는 `AI 서버 실행.command`를 실행해도 됩니다.
3. 설치·공식 모델 확인이 끝나면 `http://127.0.0.1:8001`에서 사진을 선택하고 **사진 분석하기**를 누릅니다.

첫 실행은 가상환경 생성, 고정 버전 라이브러리 설치와 가중치 다운로드가 필요해 시간이 걸립니다. 이후에는 설치 결과와 다운로드 모델을 재사용합니다. Python 환경은 현재 AI/.venv에 생성하며 다른 프로젝트 가상환경에 의존하지 않습니다. 실행 폴더에 공백이 있어도 됩니다.

Hugging Face 모델 이용 승인과 로그인은 필수입니다. 이미 승인받은 계정의 로컬 로그인을 사용합니다. 로그인하지 않았다면 설치 후 AI 폴더에서 `.venv/bin/hf auth login`을 실행하고 `bash run.sh`를 다시 실행하세요. 토큰은 채팅이나 소스에 적지 않습니다. 모델 파일을 ZIP에 넣어 승인을 대신하지 않습니다.

- 종료: 서버를 실행한 터미널에서 Ctrl+C
- 8001 포트 사용 중: 기존 서버를 임의 종료하지 않습니다. `bash run.sh --port 8002`로 다른 포트를 사용할 수 있습니다.
- 브라우저 자동 열기 생략: `bash run.sh --no-browser`
- 설치만 확인: `bash run.sh --install-only`
- 폴더 위치를 옮긴 뒤 가상환경 경로 오류: AI/.venv를 새 위치에서 다시 생성합니다. 가상환경은 ZIP에 포함하지 않습니다.

이 경로에서 검증하는 것은 **AI 단독 서버와 AI 안의 사진 테스트 화면**입니다. Flutter 앱 전체의 연동이나 BE 서버 실행을 보장하는 변경이 아닙니다. FE·BE 파일은 수정하지 않습니다.

## 현재 기능

- FastAPI `POST /v1/analyze`: 정면 전신 사진 1장의 MediaPipe 관절 기울기·비율과 DINOv3 상완 특징을 반환합니다.
- 픽셀 좌표를 사용해 어깨·골반 기울기, 어깨/골반 너비 및 상체/하체 길이 비율을 계산합니다.
- 공식 DINOv3 모델을 시작 시 한 번 로딩하고 양쪽 상완의 CLS·평균 패치 특징을 추출합니다.
- JPG/PNG, 파일당 10MB, 2,500만 픽셀 제한·EXIF 보정·긴 변 1024px 축소를 적용합니다.
- 손상·단색·극단적으로 흐린 사진, 낮은 관절 신뢰도 및 전신 누락을 거절합니다. 처리 임시 파일은 응답 후 삭제합니다.
- 기존 `POST /analyze/body`는 별도 경로로 camelCase 응답과 선택적 text 입력을 유지합니다. 기존 MediaPipe 파이프라인을 호출하며 DINOv3 결과와 혼합하지 않습니다. 사진은 1~3장으로 제한합니다.

DINOv3 **근육 분류기는 학습하지 않았습니다.** 새 API는 근육 등급·균형 점수·체형 판정·목표 비교·운동 처방을 생성하지 않습니다. 기존 API의 휴리스틱 응답은 검증된 진단이나 학습된 근육 분류 결과가 아닙니다.

## AI 단독 실행

이 폴더(`AI/`)에서 Python 3.12로 실행합니다.

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements-dinov3.txt
.venv/bin/hf auth login
.venv/bin/python -m uvicorn app:app --host 127.0.0.1 --port 8001
```

공식 `facebook/dinov3-vits16-pretrain-lvd1689m` 모델 접근 승인을 받은 계정이 필요합니다. 토큰을 코드에 적거나 공유하지 않습니다. 승인된 로컬 모델이 있으면 `DINO_MODEL_PATH=/절대/모델/폴더`를 지정할 수 있습니다. `AI_DEVICE`는 기본 `cpu`이며 `auto`도 지원합니다. 모델·사진·DB·토큰은 저장소에 포함하지 않습니다.

- 상태 확인: `http://127.0.0.1:8001/health`
- 사진 테스트 화면: `http://127.0.0.1:8001`
- API 문서: `http://127.0.0.1:8001/docs`
- DINOv3 요청:

```sh
curl -X POST http://127.0.0.1:8001/v1/analyze \
  -F 'front_images=@/절대/경로/photo.jpg'
```

응답과 오류 계약은 [DINOv3 API 명세](docs/dinov3-api.md)를 확인하세요. 이 브랜치에는 Spring 저장·JWT·할당량·Flutter 화면 변경이 없습니다. 연동은 각 담당자가 이 명세를 기준으로 구현해야 합니다.

## 검사

```sh
.venv/bin/python -m pip install -r requirements-test.txt
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests -v
```

API 경계 테스트는 가짜 엔진을 사용하며 모델이나 개인 사진을 다운로드하지 않습니다. 실제 추론 여부는 별도 모델 실행 검사와 구분합니다. 검증 범위는 [리뷰 기록](docs/ai-only-review-2026-10-31.md)을 확인하세요.

## 남은 기능

실제 검수 라벨을 사용한 윤곽 분류 학습, 다중 인물·정면·의복 검사, 측면 목 분석, 목표 비교, 추천 루틴은 후속 작업입니다. AI API에 JWT·사용자별 제한·DB·분산 큐는 없습니다. 한 번에 한 요청만 처리하고 사용 중이면 503을 반환합니다. 외부에 직접 공개하지 않고 로컬 또는 제한된 네트워크에서 사용합니다. 과거 모델 비교 자료는 연구 계획이며 현재 구현 범위는 이 README와 새 API 명세를 따릅니다.

## 커밋 전 범위 검사

Git 체크아웃의 `AI/`에서 `python scripts/check_scope.py`를 실행합니다. 기준 브랜치가 다르면 마지막 인자로 지정합니다. 커밋된 변경·작업 중 변경·미추적 파일에 AI 밖의 경로가 있으면 실패합니다.

## ZIP 검증 결과

GitHub ZIP을 실제로 다운로드해 새 가상환경 생성·설치·모델 다운로드·서버 실행·실제 사진 분석과 브라우저 결과 표시를 확인했습니다. [실행 검증 기록](docs/zip-startup-verification-2026-10-31.md)을 참고하세요. 검증 환경은 Apple Silicon Mac/Python 3.12입니다.


## 상완 윤곽 라벨링·학습 준비

사람이 검수할 로컬 라벨링 화면과 학습·평가 도구를 제공합니다. 실제 라벨이 없으면 학습하지 않고 안내합니다. 사진상 윤곽을 분류하는 도구이며 근육량이나 근력 등급을 추정하지 않습니다.

AI 서버 실행 후 다른 터미널의 AI 폴더에서:

```sh
.venv/bin/python scripts/label_contours.py --images /절대/사진/폴더
# http://127.0.0.1:8002에서 사람이 검수·저장
.venv/bin/python scripts/train_contours.py --validate-only
.venv/bin/python scripts/train_contours.py
```

검수한 인물 ID로 train/val/test를 분리합니다. 자세한 기준·명령·모델 연결은 [상완 윤곽 학습 안내](docs/contour-training.md)를 확인하세요. 실제 사진과 라벨·모델은 AI/.runtime에만 저장하며 GitHub에는 포함하지 않습니다.
