# MOVID AI 서버

**확정 작업 범위는 `AI/` 폴더뿐입니다.** FE·BE·루트 문서·공통 설정을 변경하지 않습니다. AI 문서, 테스트, 설정도 이 폴더 안에서 관리합니다. [작업 지침](AGENTS.md)을 따릅니다.

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
.venv/bin/python -m unittest discover -s tests -v
```

API 경계 테스트는 가짜 엔진을 사용하며 모델이나 개인 사진을 다운로드하지 않습니다. 실제 추론 여부는 별도 모델 실행 검사와 구분합니다. 검증 범위는 [리뷰 기록](docs/ai-only-review-2026-10-31.md)을 확인하세요.

## 남은 기능

근육 분류 학습, 다중 인물·정면·의복 검사, 측면 목 분석, 목표 비교, 추천 루틴은 후속 작업입니다. AI API에 JWT·사용자별 제한·DB·분산 큐는 없습니다. 한 번에 한 요청만 처리하고 사용 중이면 503을 반환합니다. 외부에 직접 공개하지 않고 로컬 또는 제한된 네트워크에서 사용합니다. 과거 모델 비교 자료는 연구 계획이며 현재 구현 범위는 이 README와 새 API 명세를 따릅니다.

## 커밋 전 범위 검사

Git 체크아웃의 `AI/`에서 `python scripts/check_scope.py`를 실행합니다. 기준 브랜치가 다르면 마지막 인자로 지정합니다. 커밋된 변경·작업 중 변경·미추적 파일에 AI 밖의 경로가 있으면 실패합니다.
