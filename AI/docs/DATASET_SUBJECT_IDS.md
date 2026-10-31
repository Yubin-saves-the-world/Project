# 묶음별 인물 ID

사용자가 각 묶음의 persono1부터 독립적으로 번호를 다시 부여했다고 확인했습니다. 같은 묶음 안의 동일 ID는 같은 사람이며 묶음 간 같은 번호는 다른 사람입니다.

현재 merge_reviewed_datasets.py는 원본 contour_dataset과 새로 검수한 reviewed_arm_batch_v2만 읽습니다. local_ / safev2_ 접두사로 ID를 분리하고 라벨·제외 이유·원본 분할은 보존합니다. 중복 원본 사진은 자동으로 다른 사람으로 처리하지 않고 거절합니다. 사진 간 인물을 자동 식별하는 기능은 아닙니다.

기존 인터넷 묶음은 모두 격리했으며 현재 통합 및 학습에 사용하지 않습니다. 생성물은 AI/.runtime/merged_reviewed_dataset이며 이미 있으면 덮어쓰지 않습니다. 현재 47개 영역 중 clear 6 / medium 5 / exclude 36입니다. 이후 새 묶음을 추가하려면 SOURCES와 인물 ID 매핑을 검수한 뒤 별도 출력 경로로 새 통합본을 준비해야 합니다.
