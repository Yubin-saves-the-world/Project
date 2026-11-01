# 학습과 분리한 시험 후보 묶음

## 현재 준비 상태

기존에 내려받은 Kaggle 사람 분할 자료에서 이전 검토 목록에 없던 원본 96장을 비공개로 살펴봤습니다. 원본 4장과 상완 크롭 5개를 직접 확인해 `AI/.runtime/independent_arm_test_v1`에 준비했습니다. 이 자료는 학습에 사용하지 않았고 윤곽 라벨도 자동 생성하지 않았습니다.

현재 컴퓨터의 화면은 http://127.0.0.1:8010/ 입니다. 묶음 이름과 `독립 시험 예약` 표시를 확인하세요. 같은 원본의 양팔은 같은 임시 인물 ID를 공유합니다. 4개 그룹은 검증된 서로 다른 사람 수가 아닙니다.

동일 출처 모음의 새 사진을 골랐다는 것만으로 새로운 사람이나 외부 도메인의 독립 시험이 보장되지는 않습니다. 실제 동일인·이용 범위·최종 라벨은 사람 확인이 필요합니다. 원본·크롭·특징·라벨·라이선스 기록은 비공개 runtime에만 보관합니다.

## 라벨링할 때

1. 원본과 크롭을 함께 확인합니다.
2. weak / medium / clear / exclude 중 실제 사진에 맞는 값을 고릅니다. 등급 수를 맞추려고 라벨을 변경하지 않습니다.
3. 옷·가림·흐림·작은 크기 때문에 판단이 어려우면 제외하고 이유를 기록합니다.
4. 데이터 구분은 **최종 평가 test로 고정**됩니다. train·val로 변경해 저장할 수 없습니다.
5. 저장하고 다음을 눌러 모든 항목을 검수합니다.
6. 기존 학습 자료와 같은 사람이 있거나 동일인 여부가 불명확하면 별도로 알립니다. 같은 사람을 다른 ID로 적어 독립성을 만들 수 없습니다.

이 묶음은 모델 예측 점수를 보지 않은 상태에서 라벨을 작성합니다. 라벨을 완성한 뒤에도 독립성을 사람이 확인하고 모든 등급의 유효한 표본이 있어야 평가 명령이 실행됩니다. 5개 후보는 작은 절차 검증 묶음이며 충분한 평가 표본이 아닙니다.

## 모델 고정과 학습 혼입 방지

- purpose=independent_test인 묶음은 저장소 경계에서 test만 허용합니다.
- 기본 학습·교차검증·fit-only와 학습 자료 통합 명령은 이 묶음을 거절합니다.
- 최초 라벨 저장 전에 평가 모델을 별도 frozen-model.json으로 복사하고 해시·학습 자료·라벨 출처를 기록합니다.
- 라벨 저장 이후 모델 고정을 새로 할 수 없습니다. 이미 고정한 모델도 바꾸지 않습니다.
- 평가 명령은 고정된 모델과 지정한 모델의 해시가 다르면 거절합니다. 학습에 쓰지 않은 자료인지 사진·특징·인물 ID의 교집합도 검사합니다.
- 보호 장치는 정상 작업 중 실수로 시험 자료가 학습에 섞이는 것을 줄이는 기능입니다. 로컬 관리자의 수동 파일 변조나 모든 근접 중복·동일인을 자동으로 보장하지 않습니다.

## 같은 절차를 재현하는 명령

아직 출력이 없는 새 폴더를 지정합니다. 입력 매니페스트는 원본과 최종 크롭을 직접 검수한 자료여야 합니다.

```bash
AI/.venv/bin/python AI/scripts/prepare_reviewed_crops.py \
  --manifest AI/.runtime/independent_screening_v1/reviewed-crop-manifest.json \
  --output AI/.runtime/independent_arm_test_v1 \
  --purpose independent_test \
  --reference-model AI/.runtime/merged_reviewed_v4/model.json \
  --training-dataset AI/.runtime/merged_reviewed_v4

AI/.venv/bin/python AI/scripts/label_contours.py \
  --dataset AI/.runtime/independent_arm_test_v1 --port 8010
```

현재 컴퓨터에는 준비 결과가 있으므로 준비 명령을 반복하지 않습니다. 사진·모델·매니페스트·라벨은 GitHub ZIP에 포함되지 않습니다.

## 검수와 인물 독립성 확인 후 평가

실제로 같은 사람이 학습에 없음을 확인한 경우에만 확인 옵션을 사용합니다. 확실하지 않으면 독립 시험 점수로 보고하지 않습니다.

```bash
AI/.venv/bin/python AI/scripts/evaluate_independent_contours.py \
  --model AI/.runtime/independent_arm_test_v1/frozen-model.json \
  --training-dataset AI/.runtime/merged_reviewed_v4 \
  --test-dataset AI/.runtime/independent_arm_test_v1 \
  --output AI/.runtime/independent-test-v1-report.json \
  --confirm-independent-identities
```

후보 정확도·Macro-F1·혼동행렬, 확정 기준 통과 비율과 그 안에서의 정확도를 구분합니다. 보고서를 보고 모델·기준을 조정하면 해당 시험 자료는 다음 모델의 독립 평가 자료로 재사용할 수 없습니다. 검수 완료 전의 실제 평가 점수는 생성하지 않습니다.
