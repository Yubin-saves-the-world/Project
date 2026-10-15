# Project Vitality AI Server

전신 사진에서 자세 정렬과 체형 실루엣 비율을 계산하는 AI 서버입니다.

## 구현 상태

- 구현: MediaPipe Pose 관절 추정과 사람 영역 분할, OpenCV·NumPy를 이용한 각도·비율 계산
- 구현: 여러 사진 통합, 지표별 규칙 판정, 우선 확인 부위 및 분석 JSON 반환
- 실행 확인: 실제 사진 2장 업로드 분석과 결과 이미지 생성 성공, 사진 없는 요청에 HTTP 422 응답
- 개발 계획: DINOv3 ViT-S/16 기반 부위별 근육 윤곽 분류, EfficientNet-B0와 성능 비교
- 미완료: 근육 윤곽 라벨 데이터 구축과 모델 학습·평가, BE·FE 전체 연동 검증

현재 체형 판정은 계산된 비율에 임계값을 적용하는 방식입니다. DINOv3는 아직 설치·적용되지 않았습니다. 실행 성공은 분석 정확도 검증을 의미하지 않습니다.

## 구성

```text
AI/
├── app.py
├── requirements.txt
├── analyzers/
├── schemas/
├── sample_outputs/analysis_result.example.json
└── docs/
    ├── api-integration.md
    ├── model-selection.md
    └── model-comparison-report.docx
```

FastAPI가 요청을 받고, MediaPipe와 자체 계산 로직이 분석 결과를 만듭니다. Spring Boot는 AI 호출 및 저장, Flutter는 사진 입력과 결과 표시를 담당하는 연동 구조를 계획하고 있습니다.

## 설치와 실행

로컬 실행 확인 환경은 macOS Apple Silicon과 Python 3.12입니다. MediaPipe는 0.10.21로 고정합니다.

```bash
cd AI
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
MPLCONFIGDIR=/tmp/project-vitality-mpl python -m uvicorn app:app --host 127.0.0.1 --port 8001
```

```bash
curl --fail http://127.0.0.1:8001/health
curl --fail http://127.0.0.1:8001/analyze/body \
  -F 'front_images=@/absolute/path/front1.jpg' \
  -F 'front_images=@/absolute/path/front2.jpg' \
  -F 'text=자세 분석'
```

`front_images`는 필수 파일 필드이며 여러 장은 같은 이름을 반복합니다. `text`는 선택입니다. 요청은 multipart/form-data 형식입니다. API 탐색 문서는 서버 실행 후 `/docs`에서 확인할 수 있습니다.

## 응답

`posture`, `bodyShape`, `judgements`, `priorityParts`, `comparisonSummary`, `comparisonDetail`, `textSummary`, `debugImages`, `raw`를 반환합니다. 예시 JSON은 응답 구조를 설명하는 자료이며 정확도 평가 결과가 아닙니다.

## 한계와 연동 사항

2D 사진 기반 참고 분석이며 실제 근육량과 체지방률을 측정하지 않습니다. 옷·자세·조명·카메라 각도에 영향을 받습니다. `debugImages`는 서버 로컬 파일 경로로, 프론트에서 접근 가능한 URL이 아닙니다. 세부 연동 사항은 [API 문서](docs/api-integration.md)를 참고하세요.

사진 원본, 실측 분석 결과, 가상환경과 모델 가중치는 저장소에 포함하지 않습니다. 사전학습 모델을 배포할 때에는 해당 모델의 이용 조건을 확인해야 합니다.
