-- V1.1 · 운동 종목 시드(예시)
-- 이 파일은 api/gen/model.py 에서 생성한다. 직접 고치지 말고 model.py 를 고친 뒤 `python api/gen/build_all.py` 를 다시 실행한다.
-- 대상: MySQL 8.0 이상 (CHECK 제약과 계산 컬럼 사용). 문자셋 utf8mb4, 시간은 모두 KST.

-- 운동 종목 시드 (예시). 종목 이름·난이도·권장 세트는 팀이 검토한 뒤 확정한다.
-- 경력별 권장 세트(exercise_prescriptions)는 종목마다 3행. 처음에는 같은 값을 넣고 나중에 경력별로 나눠도 API는 그대로다.
INSERT INTO `exercises` (`name`, `target_part`, `equipment`, `difficulty`, `description`) VALUES
  ('푸시업', 'chest', 'bodyweight', 1, '손을 어깨너비보다 약간 넓게 짚고 가슴이 바닥에 가까워질 때까지 내려갔다 올라옵니다.'),
  ('덤벨 벤치프레스', 'chest', 'dumbbell', 2, '벤치에 누워 덤벨을 가슴 위로 밀어 올립니다.'),
  ('바벨 벤치프레스', 'chest', 'barbell', 3, '벤치에 누워 바벨을 가슴 중앙까지 내렸다가 밀어 올립니다.'),
  ('체스트 프레스 머신', 'chest', 'machine', 1, '등을 붙이고 손잡이를 앞으로 밉니다.'),
  ('랫 풀다운', 'back', 'machine', 1, '바를 가슴 쪽으로 끌어내리며 날개뼈를 모읍니다.'),
  ('시티드 로우', 'back', 'machine', 1, '상체를 세운 채 손잡이를 배 쪽으로 당깁니다.'),
  ('덤벨 로우', 'back', 'dumbbell', 2, '벤치에 한 손을 짚고 덤벨을 옆구리 쪽으로 당깁니다.'),
  ('바벨 로우', 'back', 'barbell', 4, '상체를 숙인 채 바벨을 배 쪽으로 당깁니다.'),
  ('바디웨이트 스쿼트', 'leg', 'bodyweight', 1, '발을 어깨너비로 벌리고 엉덩이를 뒤로 빼며 앉았다 일어납니다.'),
  ('레그 프레스', 'leg', 'machine', 1, '발판을 밀어 무릎을 펴고 천천히 돌아옵니다.'),
  ('고블릿 스쿼트', 'leg', 'dumbbell', 2, '덤벨을 가슴 앞에 들고 스쿼트합니다.'),
  ('바벨 스쿼트', 'leg', 'barbell', 4, '바벨을 어깨 뒤에 얹고 스쿼트합니다.'),
  ('숄더 프레스 머신', 'shoulder', 'machine', 1, '손잡이를 머리 위로 밀어 올립니다.'),
  ('덤벨 숄더 프레스', 'shoulder', 'dumbbell', 2, '덤벨을 어깨 높이에서 머리 위로 밀어 올립니다.'),
  ('사이드 레터럴 레이즈', 'shoulder', 'dumbbell', 2, '팔을 옆으로 어깨 높이까지 들어 올립니다.'),
  ('바벨 오버헤드 프레스', 'shoulder', 'barbell', 4, '바벨을 쇄골 위에서 머리 위로 밀어 올립니다.'),
  ('덤벨 컬', 'arm', 'dumbbell', 1, '팔꿈치를 고정하고 덤벨을 어깨 쪽으로 올립니다.'),
  ('해머 컬', 'arm', 'dumbbell', 1, '손바닥이 마주 보게 잡고 덤벨을 올립니다.'),
  ('트라이셉스 푸시다운', 'arm', 'machine', 1, '케이블을 아래로 눌러 팔을 폅니다.'),
  ('벤치 딥스', 'arm', 'bodyweight', 2, '벤치를 뒤로 짚고 팔꿈치를 굽혔다 폅니다.'),
  ('플랭크', 'core', 'bodyweight', 1, '팔꿈치와 발끝으로 몸을 일직선으로 유지합니다. 세트당 시간으로 센다.'),
  ('크런치', 'core', 'bodyweight', 1, '누워서 상체를 말아 올립니다.'),
  ('레그 레이즈', 'core', 'bodyweight', 2, '누워서 다리를 곧게 들어 올렸다 내립니다.'),
  ('케이블 크런치', 'core', 'machine', 3, '케이블을 잡고 상체를 말아 내립니다.');

INSERT INTO `exercise_prescriptions` (`exercise_id`, `experience_level`, `min_sets`, `max_sets`)
SELECT e.`exercise_id`, l.`lv`, l.`min_sets`, l.`max_sets`
FROM `exercises` e
JOIN (SELECT 'under3m' AS lv, 2 AS min_sets, 3 AS max_sets
      UNION ALL SELECT 'under1y', 3, 4
      UNION ALL SELECT 'over1y', 3, 5) l
ON 1 = 1;
