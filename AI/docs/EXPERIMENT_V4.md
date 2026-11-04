# 31영역 윤곽 분류 실험과 적용

## 사용한 자료

기존 검수 자료와 kaggle_arm_batch_v2, kaggle_arm_batch_v3, relaxed_arm_batch_v1을 새 폴더에 통합했습니다. 실제 사람이 저장한 라벨을 그대로 사용했고 기존 묶음을 덮어쓰지 않았습니다.

- 통합 항목 67개, 제외 36개, 사용 가능 31개 영역
- clear 7 / medium 19 / weak 5
- 저장된 ID 기준 인물 그룹 21개. 실제 서로 다른 사람 21명으로 검증한 수치는 아닙니다.
- 같은 사진의 좌우 상완은 같은 인물 그룹을 유지합니다.
- 기존 격리·철회 자료는 사용하지 않습니다.

## 동일 자료에서의 설정 비교

외부 3개 분할은 인물 그룹을 분리하며, 설정 조정 방식은 외부 학습 부분 안에서만 인물 그룹별 검증으로 C를 선택합니다. 같은 외부 평가 분할에서 고정 C=1과 설정 조정 방식을 비교합니다. 임계값은 양쪽 모두 0.6입니다.

| 항목 | 고정 C=1 | 내부 검증으로 C 선택 |
| --- | --- | --- |
| 후보 정확도 | 20/31, 64.5% | 19/31, 61.3% |
| 후보 Macro-F1 | 0.625 | 0.589 |
| 확정 기준 통과 | 0/31, 0% | 8/31, 25.8% |
| 기준 통과 항목의 정답 비율 | 계산 불가 | 5/8, 62.5% |

고정 방식에서 clear는 5/7, medium은 12/19, weak는 3/5가 후보 기준으로 맞았습니다. 후보는 점수와 무관하게 가장 높은 등급을 고른 값이며 실제 확정 응답과 다릅니다. 다수 등급 기준선은 19/31, 61.3%입니다.

설정 조정 방식은 확정 응답이 늘었지만 후보 정확도와 Macro-F1이 낮아졌습니다. 따라서 적용하지 않았습니다. 전체 자료 내부 검증으로 선택된 최종 C도 1입니다. 임계값을 낮추거나 시험 점수로 설정을 고르지 않았습니다.

이 비교는 작은 자료에서 반복한 개발 실험이며 독립 외부 시험이 아닙니다. 인물 ID는 사람의 확인에 의존하고, 출처·포즈·조명 편향이 남습니다. 이전 11개 또는 23개 자료의 결과와 표본 구성이 다르므로 정확도가 향상·하락했다고 직접 비교하지 않습니다.

## 적용 상태와 재현

적용 모델은 31개 전체로 학습한 고정 C=1 모델입니다. 최종 전체 학습 모델을 동일 31개로 재예측한 값을 시험 정확도로 보고하지 않습니다. 모델에는 grouped_cv_only 상태, 자료·라벨 SHA256, 학습 영역 수를 기록합니다. 학습 중 자료가 바뀌면 모델 저장을 거절합니다.

프로젝트 루트에서 통합 폴더가 없다면:

```bash
AI/.venv/bin/python AI/scripts/merge_reviewed_datasets.py \
  --include kaggle2=kaggle_arm_batch_v2 \
  --include kaggle3=kaggle_arm_batch_v3 \
  --include relaxed=relaxed_arm_batch_v1 \
  --output AI/.runtime/merged_reviewed_v4
```

```bash
AI/.venv/bin/python AI/scripts/train_contours.py \
  --dataset AI/.runtime/merged_reviewed_v4 --evaluation grouped-cv
AI/.venv/bin/python AI/scripts/benchmark_contours.py \
  --dataset AI/.runtime/merged_reviewed_v4

AI_REVIEWED_DATASET="$PWD/AI/.runtime/merged_reviewed_v4" \
AI_CONTOUR_MODEL="$PWD/AI/.runtime/merged_reviewed_v4/model.json" \
bash AI/run.sh --port 8005
```

Flutter 시연 연결도 동일 모델로 실행할 수 있습니다.

```bash
AI_REVIEWED_DATASET="$PWD/AI/.runtime/merged_reviewed_v4" \
bash AI/run-flutter.sh \
  --contour-model "$PWD/AI/.runtime/merged_reviewed_v4/model.json"
```

기존 모델로 복구하려면 --contour-model을 이전 파일로 지정하고 서버를 재시작합니다. 이전 23영역 모델은 AI/.runtime/models/contour-home-v1/model.json에 보존합니다. 사진·라벨·특징·모델은 GitHub ZIP에 포함하지 않습니다. 위 명령은 해당 로컬 검수 자료가 있는 환경에서 실행합니다.

## 다음 평가

31개 학습 자료는 더 이상 독립 시험에 사용할 수 없습니다. 새로 확보한 사진에서 사람이 동일인·등급을 확인한 뒤 독립 평가 도구를 사용해야 합니다. 모든 등급과 다양한 사람·포즈·조명이 포함돼야 합니다. 건강 점수·근육량·근력·정상 체형을 검증한 결과가 아닙니다.
