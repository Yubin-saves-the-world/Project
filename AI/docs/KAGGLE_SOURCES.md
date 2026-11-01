# Kaggle 원본 수집과 사용 구분

사용자가 선택한 후보 5종을 AI/.runtime/kaggle_sources 안에서만 관리합니다. 원본 ZIP·사진·치수·PDF·다운로드 기록은 Git에 포함하지 않습니다. 코드·검사·설명만 AI/ 안에 둡니다.

## 수집과 점검

```sh
.venv/bin/python scripts/import_kaggle_sources.py
.venv/bin/python scripts/audit_kaggle_sources.py
```

공개 API의 데이터 버전을 고정해 ZIP을 다운로드하고 SHA256·실제 파일 목록·라이선스 표기·원본 메타데이터를 기록합니다. 인증서 검증을 유지합니다. OS 인증서를 사용해야 하는 환경에서는 requirements-dev.txt에 고정된 truststore를 설치할 수 있습니다. API 자격 증명은 소스나 출력에 기록하지 않으며 유료 전체 데이터의 접근 제한을 우회하지 않습니다.

완료한 아카이브는 재실행 시 해시를 확인하고 다시 내려받지 않습니다. 파일당 최대 5GiB, 디스크 여유 최소 5GiB를 유지합니다. ZIP 경로 탈출·심볼릭 링크·암호화 항목·과도한 크기를 거절합니다. 자동으로 전체 압축을 풀거나 파일을 실행하지 않습니다. 실패 또는 HTML 로그인 응답을 정상 데이터로 등록하지 않습니다.

## 후보와 실제 활용 방향

| 키 | Kaggle | 용도 |
|---|---|---|
| body_measurements | unidpro/body-measurements-image-dataset | 실제 인체 사진과 치수 대응을 검토할 후보. 공개 ZIP은 6명 폴더의 JPG 78개, 추가 PNG 1개, CSV 2개이며 소개된 전체 사진 수와 다릅니다. |
| body_size | tapakah68/body-measurements-dataset | 공개 ZIP은 CSV와 PDF 각 1개. CSV 21행은 상대 파일 경로를 가리키지만 해당 사진·측정 JSON은 ZIP에 없습니다. 없는 사진을 확보했다고 계산하지 않습니다. |
| somaset | vicolab/somaset | 합성 인물의 자세·의복·시점 변화에 대한 전처리 시험 후보. 10만 이미지를 실제 사람 10만 명으로 계산하지 않습니다. |
| person_segmentation | tapakah68/supervisely-filtered-segmentation-person-dataset | 원본과 분할 마스크를 구분해 전처리·분할 검증 후보로 관리합니다. 마스크·콜라주를 새 사람 사진으로 중복 계산하지 않습니다. |
| body_fat | fedesoriano/body-fat-prediction-dataset | bodyfat.csv의 252행·15개 수치 열. 실제 치수 입력을 사용하는 별도 수치 분석 자료이며 DINOv3 이미지 입력이나 상완 윤곽 정답이 아닙니다. |

UniData에는 6행의 공개 사진 대응 CSV 외에 43행의 메타데이터 CSV도 있습니다. 메타데이터에 43명이 있다고 그 43명의 사진이 다운로드된 것은 아닙니다.

SOMASet는 CC BY-NC-SA 4.0으로 표시되어 있으며, 나머지 인체 사진 후보에는 CC BY-NC-ND 4.0 표기가 있습니다. 수치 데이터는 원저자 조건을 확인합니다. source.json과 metadata.json에 실제 표기를 보관하며, 크롭·파생 자료·발표 공개 등의 사용 범위는 원출처 조건을 확인합니다. 단순 다운로드가 학습·공개 승인을 뜻하지 않습니다.

## 기존 분류 학습과 분리

다운로드 원본은 downloaded_unreviewed 상태입니다. 기존 contour_dataset·merged_reviewed_dataset·실행 모델을 자동 변경하지 않습니다. 검수되지 않은 원본은 8002 라벨링 화면에 노출하지 않습니다. 이전에 격리한 인터넷 자료도 재사용하지 않습니다.

점검 명령은 usage-plan.json과 review-queue.json을 만듭니다. 큐는 원본 ZIP 안에서 확인할 후보 목록이며, 라벨링 dataset.json이 아닙니다. 다음 조건이 충족되기 전에는 사진을 학습용 상완으로 등록하지 않습니다.

1. 자료 이용 범위 확인
2. 원본 전체의 적절성·인물·의복 확인
3. 상완 크롭 위치·가림 확인
4. 사람의 윤곽 라벨 저장
5. 동일 인물이 학습·평가에 섞이지 않도록 분할

공개 사진 폴더 ID는 kaggle_measurements_person*, 합성 ID는 kaggle_somaset_avatar*로 분리합니다. 일반 분할 데이터에서 다른 파일이라는 이유만으로 서로 다른 사람이라고 가정하지 않습니다. 합성 체형·분할 마스크·체지방 수치를 weak/medium/clear 윤곽 라벨로 임의 변환하지 않습니다.

## 실제 사진 실행 확인

UniData 공개본의 6명 정면·측면 12장은 원본을 직접 확인했습니다. 자료의 age 열도 성인 범위인지 확인했으며 이 확인은 외모로 나이를 추정한 것이 아닙니다. 일부 사진은 긴팔·머리카락 가림과 낮은 카메라 위치가 있어 상완 윤곽 등급용으로 자동 승인하지 않습니다.

이 6쌍으로 로컬 /v1/analyze를 실제 호출했을 때 5쌍은 정면·측면 측정을 완료했고 1쌍은 필수 관절 신뢰도 부족(NOT_FULL_BODY)으로 거절됐습니다. 이는 실행 성공 여부를 검사한 결과이며 측정 정확도·근육 분류 성능 평가가 아닙니다. 원본 검수 기록과 실행 결과는 비공개 원본 폴더에만 보관합니다.

다운로드·원본 검수·상완 크롭 검수·사람 라벨 저장은 다른 단계입니다. 원본 일부를 확인했다고 모든 사진이나 크롭을 검수 완료로 계산하지 않습니다. 수집·아카이브 검사·실제 파일 수·CSV 누락 참조·검수 단계 분리 등을 포함한 코드 검사 83개가 통과했습니다.
