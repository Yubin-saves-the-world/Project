# 검수 라벨 재학습과 실제 연결 확인

모든 명령은 프로젝트 루트에서 실행합니다. FE/BE 원본과 공통 설정은 수정하지 않습니다.

## 1. 검수 완료 자료 통합

```bash
AI/.venv/bin/python AI/scripts/merge_reviewed_datasets.py \
  --include kaggle2=kaggle_arm_batch_v2 \
  --output AI/.runtime/merged_with_kaggle_v2
```

기존 출력은 덮어쓰지 않습니다. 이미 통합했다면 생략하고, 라벨을 수정했다면 새로운 출력 이름으로 다시 통합합니다. 입력 묶음은 AI/.runtime 안에 있어야 하며 모든 후보의 실제 검수 저장이 필요합니다. 검수 원본·크롭 해시가 있는 항목은 통합과 학습 양쪽에서 변경 여부를 확인합니다.

## 2. 평가 가능한지 먼저 확인

```bash
AI/.venv/bin/python AI/scripts/train_contours.py \
  --dataset AI/.runtime/merged_with_kaggle_v2 \
  --evaluation grouped-cv --validate-only
```

각 등급에서 최소 3개 인물 그룹이 필요합니다. 이는 실행 최소 조건이며 충분한 데이터나 정확도 보장을 뜻하지 않습니다. 사진별 임시 ID는 실제 동일인 여부를 사람이 확인해야 합니다. 조건을 충족하면 `--validate-only` 없이 교차검증을 실행할 수 있습니다.

## 3. 평가 조건 미달 시 명시적인 실험 학습

```bash
AI/.venv/bin/python AI/scripts/train_contours.py \
  --dataset AI/.runtime/merged_with_kaggle_v2 \
  --evaluation fit-only \
  --output AI/.runtime/models/contour-reviewed-20261101
```

이 명령은 입력의 train/val/test 구분을 포함한 모든 사용 가능 검수 행으로 고정 C=1 분류기를 학습합니다. 기존 분할은 변경하지 않지만 **이 모델에 대해 해당 자료는 더 이상 미사용 평가 자료가 아닙니다.** 보고서의 evaluation은 null이며 정확도·F1을 만들지 않습니다. 새로운 독립 평가 자료가 필요합니다. 보류 기준은 0.6으로 유지하며 기존 모델·출력은 덮어쓰지 않습니다.

2026-11-01 실제 저장 자료 기준으로 59개 검수 항목 중 제외 36개를 빼고 23개 영역(clear 7 / medium 15 / weak 1)을 학습했습니다. 인물 그룹 16개는 검증된 서로 다른 사람 수가 아닙니다. weak는 1개 인물 그룹이라 교차검증 조건을 충족하지 못했습니다. 정식 명령으로 생성한 계수는 이전 로컬 실험 모델과 일치했습니다.

## 4. Flutter 실행과 자동 연결 검사

```bash
bash AI/run-flutter.sh \
  --contour-model "$PWD/AI/.runtime/models/contour-reviewed-20261101/model.json"
```

기존 사진을 QA 기기 앨범에 추가하려면 `--photo "/사진/test1.jpg"`를 함께 지정합니다. 실행기는 분류기 형식·가중치·공식 특징 버전을 인증 서버 빌드 전에 확인합니다. 분류기를 지정하지 않으면 기본 사진 측정이 가능합니다.

서버 준비 후 다른 터미널에서:

```bash
AI/.venv/bin/python AI/scripts/verify_flutter_flow.py \
  --photo "/사진의/절대경로/test1.jpg"
```

로컬 8080의 상태 확인 → 실제 Spring 시연 로그인 → 새 사진 업로드 → 분석 작업 → 결과 조회와 필수 측정값을 검사합니다. 검사에서 올린 사진만 완료 후 삭제합니다. 토큰·사진·특징은 보고서에 넣지 않습니다. 보고서는 AI/.runtime/flutter-flow-check.json에 저장하며 Git에 포함하지 않습니다. 기본 계정 비밀번호를 바꿨다면 환경 변수 AI_DEMO_PASSWORD에 기존 값을 지정합니다. 외부 서버와 리디렉션은 거절하고 환경 프록시를 사용하지 않습니다.

이 명령은 HTTP 연결 검사이며 앱 UI나 실제 카메라 검사를 대신하지 않습니다. 기존 Flutter의 사진 선택 → 분석 시작 → 체형 측정 표시도 별도로 확인해야 합니다. 모델 정체성은 `/health`의 contour_model.sha256·classes·validation_status로 확인하며 파일 경로·토큰은 노출하지 않습니다.

## 남은 제한

- 검증된 근육량·근력·건강 점수·전신 체형 분류를 제공하지 않습니다.
- 상완 윤곽 후보는 사람의 피부·위치 확인이 필요하고 기준 미달 시 보류됩니다.
- 기존 Flutter에는 윤곽 검수·후보 상세 UI가 없습니다. 점수 미제공 문구 수정은 FE 담당 범위입니다.
- 개인 사진·라벨·학습 모델·가상환경은 GitHub ZIP에 포함하지 않습니다.
- 공식 DINOv3 이용 승인·로그인·다운로드와 Flutter/Xcode/Java 준비가 필요합니다.
