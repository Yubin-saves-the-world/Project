# 현재 동작 범위와 새 실험

## 최신 상태 (2026-11-01)

새 Kaggle 검수 12개를 합쳐 23개 사용 가능 영역(clear 7 / medium 15 / weak 1)으로 정식 fit-only 명령을 실행했습니다. 인물 그룹 16개는 사진별 임시 ID를 포함하며 실제 동일인 여부 확인이 필요합니다. weak가 1개 그룹이라 교차검증 조건은 여전히 미달입니다. 새 모델에는 평가 점수가 없으며 아래 11영역 모델의 과거 수치를 새 모델의 정확도로 사용하지 않습니다. [재학습·연결 검사 명령과 제한](RETRAIN_AND_VERIFY.md)을 확인하세요.

아래 내용은 이전 11영역 모델의 실험 기록입니다.

원본 사용자 사진과 새로 원본·크롭을 직접 검수하고 사람이 라벨을 저장한 v2 자료만 사용합니다. 기존 격리 자료와 철회 모델은 사용하지 않습니다. 추가 v3 묶음의 서버 저장 파일은 아직 없어 이번 학습에 포함하지 않았습니다.

현재 통합 47개 영역 중 제외 36개를 빼고 11개 영역(7개 인물, clear 6 / medium 5)을 사용했습니다. 독립 학습·검증·시험 분할의 최소 인물 조건은 충족하지 못합니다. 따라서 기존 holdout 검사를 완화해 통과했다고 하지 않고, 별도 명시적인 초기 실험 프로토콜을 사용합니다.

## 인물별 교차검증

3분할 StratifiedGroupKFold, 각 분할에서 같은 인물의 영역은 학습/평가에 중복되지 않습니다. 평가 인물을 학습하지 않은 모델로 각 영역을 한 번씩 예측합니다. 인물별 분할은 등급의 최소 분포만으로 미리 정하며 모델 점수로 고르지 않습니다. C=1, 클래스 가중 balanced, 보류 임계값 0.6을 고정했습니다. 별도 하이퍼파라미터 탐색은 하지 않습니다. 독립 외부 시험 결과라는 의미가 아닙니다.

- 교차검증 정확도 8/11(72.7%), Macro-F1 약 0.718
- 학습 분할 다수 등급으로만 답하는 기준 6/11(54.5%)
- 혼동행렬: clear 6개 중 5개 정답 / medium 5개 중 3개 정답
- 평가 시 임계값 0.6을 넘은 비율은 0%입니다. 확정 분류용 성능이 부족합니다.
- 최종 실험 모델은 검수된 11개 전체로 학습했습니다. 교차검증 점수는 이 최종 모델의 학습 데이터 재예측 점수가 아닙니다.

모델·상세 보고서·CV 분할 계획은 AI/.runtime/merged_reviewed_dataset에만 보관합니다. 코드만 GitHub에 올리며 모델·사진·특징·라벨은 공개하지 않습니다. 원본 라벨은 변경하지 않았습니다.

## 재현 명령 (AI 폴더)

```sh
.venv/bin/python scripts/merge_reviewed_datasets.py
.venv/bin/python scripts/train_contours.py --dataset .runtime/merged_reviewed_dataset --evaluation grouped-cv --validate-only
.venv/bin/python scripts/train_contours.py --dataset .runtime/merged_reviewed_dataset --evaluation grouped-cv
AI_CONTOUR_MODEL="$PWD/.runtime/merged_reviewed_dataset/model.json" bash run.sh --port 8003 --no-browser
```

통합 명령은 기존 출력이 있으면 덮어쓰지 않습니다. 이미 통합한 경우 첫 명령을 생략합니다. 원본·검수 자료가 없는 새 ZIP에서는 먼저 실제 사진 준비와 사람 라벨링이 필요합니다. 기본 서버는 임의의 학습 모델을 대신 생성하지 않습니다.

## 직접 테스트

http://127.0.0.1:8003/contour-test 에서 상완 크롭 JPG/PNG를 선택하고 의복 가림·부적절한 노출이 없는지 확인 체크 후 분석합니다. 서버 API는 POST /v1/contour/classify, multipart image 및 skin_visible_confirmed=true입니다.

반환값은 classification.status, label, candidate_label, model_score, probabilities, experimental입니다. 임계값 미만이면 status=abstained, label=null이며 candidate_label은 참고 후보로만 표시합니다. 후보 점수는 정확도나 건강 점수가 아닙니다. 실제 새 크롭 요청에서 medium 후보 0.58229, 보류 상태로 반환하는 것을 확인했습니다. 시험 점수를 높이려고 임계값을 낮추지 않았습니다.

일반 전신 /v1/analyze와 Flutter 연결 경로에서는 의복 가림을 자동 판정할 수 없어 새 모델로 윤곽 등급을 자동 확정하지 않습니다. 새 윤곽 분류는 별도 상완 크롭 테스트 또는 새 AI 웹에서 피부·위치를 사람이 확인한 크롭에 한정합니다. [v2 계약](PHOTO_ANALYSIS_V2.md)을 확인하세요. Flutter의 기울기·비율 측정 연결은 유지하며 FE/BE는 수정하지 않습니다.

현재 구현된 것은 실제 동작하는 초기 실험·평가·API·테스트 화면입니다. 근육량·근력·균형 점수·건강 판단·검증된 실사용 분류 성능의 완성을 뜻하지 않습니다.

## 학습 설정 병목 점검

`benchmark_contours.py`는 기존 모델을 덮어쓰지 않고 학습 설정을 비교합니다. 외부 3개 인물 분리 평가 안에서 다시 인물별 leave-one-subject-out 검증을 수행하여 C=1/10/100 중 하나를 고릅니다. 선택 지표는 내부 예측을 합친 Macro-F1이고 동점이면 작은 C를 유지합니다. 외부 평가 인물은 내부 선택에 포함하지 않으며 보류 임계값은 0.6으로 유지합니다.

```sh
.venv/bin/python scripts/benchmark_contours.py --dataset .runtime/merged_reviewed_dataset
```

현재 7명·11영역의 동일 자료에서 고정 C=1과 내부 선택 방식 모두 정확도 8/11, Macro-F1 약 0.718, 확정 비율 0%였습니다. 전체 자료 내부 검증으로 선택된 C도 1입니다. 이 비교에서는 개선이 확인되지 않았습니다. 다른 모든 모델 설정이 효과 없다고 입증한 것은 아닙니다. 반복해서 같은 작은 자료를 실험하고 있으므로 독립 성능 검증으로 보고하지 않습니다.

후보 모델과 보고서는 데이터셋의 nested-candidate-model.json / nested-benchmark-report.json에만 저장합니다. 기존 model.json과 실행 중인 서버는 교체하지 않습니다. 확정 비율만 높아지는 것을 정확도 개선으로 취급하지 않습니다.

데이터 병목도 실제 저장 라벨로 확인했습니다. 통합 47개 영역 중 제외 36개의 이유는 의복 가림 35개, 의복·머리카락 가림 1개입니다. 제외 기준을 풀어 잘못된 정답을 늘리지 않습니다. 현재 weak 등급이 없으며 추가 v3 묶음의 4개는 아직 서버 저장 라벨이 없어 학습하지 않습니다.

추가 검사에서 잘못된 관절 좌표·누락 값·범위를 벗어난 visibility는 크롭을 생성하지 않고 None으로 처리하도록 보강했습니다. 관련 검사와 인물 분리·기존 모델 보존 검사를 포함해 총 74개 테스트가 통과했습니다.
