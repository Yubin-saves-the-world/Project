# 측정 설명 응답과 다음 학습 단계

`POST /v1/analyze` 및 Flutter 연결 계층의 완료 결과에 `measurement_report`가 추가됩니다. 기존 측정 필드와 null 점수는 유지합니다. FE/BE는 수정하지 않습니다. 기존 Flutter는 추가 필드를 표시하지 않으므로 화면의 ‘산출 불가’ 문구는 그대로입니다.

- `title`, `summary`: 실제 측정값을 요약합니다.
- `items`: 항목별 key/title/status/value/unit/display_value/description/meaning/limitation.
- `features`: 좌우 상완의 특징 추출 상태와 선택적 윤곽 분류 결과. 추출과 분류를 구분합니다.
- `capabilities`: 점수·체형·근육 등급은 not_implemented, 윤곽 분류기 미설정은 not_trained.
- `next_steps`: 같은 촬영 조건으로 비교하기 위한 안내.

임의의 정상 기준, 건강 점수, 근육 발달 등급을 생성하지 않습니다. null/NaN/무한대는 측정값으로 설명하지 않습니다. 기존 text_summary와 summary도 측정 요약을 반환합니다.

## 학습 진행

기존 도구의 사전 검사를 실행했으며 사람이 검수한 라벨이 없어 학습을 진행하지 않았습니다. 사람이 확인하지 않은 사진을 임의 라벨로 학습시키지 않습니다. 사진에서 관찰 가능한 상완 윤곽 가시성만 분류 대상으로 합니다.

AI 폴더에서 다음 순서로 진행합니다.

```sh
# 이미 준비된 사진과 특징으로 라벨링 화면 실행
.venv/bin/python scripts/label_contours.py
# http://127.0.0.1:8002 에서 검수 저장 후
.venv/bin/python scripts/train_contours.py --validate-only
.venv/bin/python scripts/train_contours.py
# 평가 보고서를 확인한 뒤 선택적으로 연결
AI_CONTOUR_MODEL="$PWD/.runtime/contour_dataset/model.json" bash run.sh
```

같은 사람은 모든 사진과 좌우 상완에 같은 인물 ID를 사용합니다. 옷으로 가려진 영역은 weak가 아니라 exclude입니다. 실제 이름은 입력하지 않습니다. train/val/test 사이에 같은 사람이 들어가지 않게 합니다. 최소 데이터 조건과 라벨 정의는 [학습 안내](contour-training.md)를 따릅니다. 현재 사진 수만으로 목표 성능을 보장하지 않습니다.

자동 검사는 총 43개 통과했습니다. 테스트용 특징으로 분류기 코드가 작동하는 것과 실제 분류 성능을 구분합니다. 학습 모델은 사람이 검수한 라벨을 입력하고 별도 인물의 검증·시험 결과를 확인한 뒤 적용합니다.
