-- V1 · MVP 테이블
-- 이 파일은 api/gen/model.py 에서 생성한다. 직접 고치지 말고 model.py 를 고친 뒤 `python api/gen/build_all.py` 를 다시 실행한다.
-- 대상: MySQL 8.0 이상 (CHECK 제약과 계산 컬럼 사용). 문자셋 utf8mb4, 시간은 모두 KST.

-- 회원 · MVP
CREATE TABLE `users` (
  `user_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '회원 ID',
  `email` VARCHAR(255) NULL COMMENT '소문자로 저장·비교. 탈퇴하면 NULL (같은 이메일로 재가입 가능)',
  `password_hash` VARCHAR(60) NULL COMMENT 'BCrypt 해시. 구글·카카오로 만든 계정은 NULL',
  `nickname` VARCHAR(30) NOT NULL COMMENT '2~20자(API 검증). 탈퇴하면 withdrawn_{user_id}로 바꿔 유일성을 유지하고, 화면에는 "탈퇴한 사용자"로 보여준다',
  `role` VARCHAR(10) NOT NULL DEFAULT 'user' COMMENT '권한',
  `status` VARCHAR(10) NOT NULL DEFAULT 'active' COMMENT '탈퇴하면 withdrawn. 모든 요청에서 확인해 토큰이 남아 있어도 막는다',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '가입 시각',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '마지막 수정',
  `deleted_at` DATETIME NULL COMMENT '탈퇴 시각',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uq_users_email` (`email`),
  UNIQUE KEY `uq_users_nickname` (`nickname`),
  CONSTRAINT `ck_users_role` CHECK (`role` IN ('user', 'admin')),
  CONSTRAINT `ck_users_status` CHECK (`status` IN ('active', 'withdrawn'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='회원';

-- 동의 이력 · MVP
CREATE TABLE `user_consents` (
  `consent_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '이력 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `consent_type` VARCHAR(20) NOT NULL COMMENT '이용약관 / 개인정보 / 신체 사진 / AI 처리',
  `agreed` TINYINT(1) NOT NULL COMMENT 'true 동의, false 철회',
  `policy_version` VARCHAR(30) NOT NULL COMMENT '동의한 약관 버전 (예: 2026-10-01)',
  `source` VARCHAR(10) NOT NULL COMMENT '어디서 동의했는지',
  `agreed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '동의·철회 시각',
  PRIMARY KEY (`consent_id`),
  KEY `idx_consent_latest` (`user_id`, `consent_type`, `consent_id`),
  CONSTRAINT `fk_user_consents_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_user_consents_consent_type` CHECK (`consent_type` IN ('terms', 'privacy', 'body_photo', 'ai_processing')),
  CONSTRAINT `ck_user_consents_source` CHECK (`source` IN ('signup', 'settings', 'google', 'kakao'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='동의 이력';

-- 신체정보 이력 · MVP
CREATE TABLE `user_profiles` (
  `profile_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '이력 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `height_cm` DECIMAL(4,1) NOT NULL COMMENT '키',
  `weight_kg` DECIMAL(4,1) NOT NULL COMMENT '몸무게',
  `age` TINYINT NOT NULL COMMENT '나이',
  `gender` VARCHAR(6) NOT NULL DEFAULT 'none' COMMENT '성별. 입력받지 않으면 none',
  `goal_type` VARCHAR(10) NOT NULL COMMENT '운동 목적',
  `weekly_frequency` TINYINT NOT NULL COMMENT '주 운동 가능 횟수',
  `experience_level` VARCHAR(10) NOT NULL COMMENT '운동 경력',
  `measured_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '이 값이 기록된 시각',
  PRIMARY KEY (`profile_id`),
  KEY `idx_profile_latest` (`user_id`, `profile_id`),
  CONSTRAINT `fk_user_profiles_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_user_profiles_gender` CHECK (`gender` IN ('male', 'female', 'none')),
  CONSTRAINT `ck_user_profiles_goal_type` CHECK (`goal_type` IN ('muscle', 'diet', 'posture')),
  CONSTRAINT `ck_user_profiles_experience_level` CHECK (`experience_level` IN ('under3m', 'under1y', 'over1y')),
  CONSTRAINT `ck_profile_height` CHECK (height_cm BETWEEN 100 AND 250),
  CONSTRAINT `ck_profile_weight` CHECK (weight_kg BETWEEN 30 AND 250),
  CONSTRAINT `ck_profile_age` CHECK (age BETWEEN 10 AND 100),
  CONSTRAINT `ck_profile_freq` CHECK (weekly_frequency BETWEEN 1 AND 7)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='신체정보 이력';

-- 사진 · MVP
CREATE TABLE `photos` (
  `photo_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '사진 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `type` VARCHAR(10) NOT NULL COMMENT 'current 현재 체형 / goal 목표 체형(임시)',
  `side` VARCHAR(10) NOT NULL DEFAULT 'front' COMMENT '촬영 방향',
  `storage_key` VARCHAR(255) NOT NULL COMMENT 'S3 객체 키 (예: photos/12/3f2a….jpg)',
  `content_type` VARCHAR(20) NOT NULL COMMENT '파일 내용(매직 바이트)으로 판별한 형식',
  `size_bytes` INT NOT NULL COMMENT '파일 크기',
  `expires_at` DATETIME NULL COMMENT '목표 사진만: 업로드 + 1시간. 이 시각까지 목표로 등록하지 않으면 삭제한다',
  `deleted_at` DATETIME NULL COMMENT '삭제 요청 시각. 값이 있으면 접근을 막고, S3에서 지운 것을 확인하면 행을 지운다',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '업로드 시각',
  PRIMARY KEY (`photo_id`),
  UNIQUE KEY `uq_photos_storage_key` (`storage_key`),
  KEY `idx_photo_user` (`user_id`, `type`, `created_at`),
  KEY `idx_photo_expire` (`expires_at`),
  KEY `idx_photo_deleted` (`deleted_at`),
  CONSTRAINT `fk_photos_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_photos_type` CHECK (`type` IN ('current', 'goal')),
  CONSTRAINT `ck_photos_side` CHECK (`side` IN ('front', 'side', 'back')),
  CONSTRAINT `ck_photos_content_type` CHECK (`content_type` IN ('image/jpeg', 'image/png')),
  CONSTRAINT `ck_photo_size` CHECK (size_bytes <= 10485760)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='사진';

-- 목표 체형 · MVP
CREATE TABLE `goal_bodies` (
  `goal_body_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '목표 체형 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원 (사용자당 1개)',
  `status` VARCHAR(10) NOT NULL COMMENT '사진 목표는 pending에서 시작. 설명만 있으면 바로 done',
  `description` VARCHAR(200) NULL COMMENT '사용자가 쓴 설명',
  `summary` VARCHAR(500) NULL COMMENT 'AI가 목표 사진에서 뽑은 특징 요약',
  `error_message` VARCHAR(100) NULL COMMENT 'status=failed일 때 사용자에게 보여줄 문장',
  `source_photo_id` BIGINT NULL COMMENT '처리 중인 목표 사진. 처리가 끝나 사진을 지우면 NULL',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록 시각',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',
  PRIMARY KEY (`goal_body_id`),
  UNIQUE KEY `uq_goal_bodies_user_id` (`user_id`),
  KEY `idx_goal_pending` (`status`, `updated_at`),
  CONSTRAINT `fk_goal_bodies_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_goal_bodies_source_photo_id` FOREIGN KEY (`source_photo_id`) REFERENCES `photos` (`photo_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_goal_bodies_status` CHECK (`status` IN ('pending', 'done', 'failed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='목표 체형';

-- 체형 분석 · MVP
CREATE TABLE `body_analyses` (
  `analysis_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '분석 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `source` VARCHAR(10) NOT NULL DEFAULT 'photo' COMMENT '사진 분석 / 글 분석',
  `status` VARCHAR(10) NOT NULL DEFAULT 'pending' COMMENT '진행 상태',
  `error_code` VARCHAR(20) NULL COMMENT 'status=failed일 때만',
  `error_message` VARCHAR(100) NULL COMMENT '사용자에게 보여줄 실패 사유',
  `photo_id` BIGINT NULL COMMENT '정면 사진. 사진을 지우면 NULL',
  `side_photo_id` BIGINT NULL COMMENT '측면 사진 (없으면 NULL)',
  `goal_body_id` BIGINT NULL COMMENT '비교에 쓴 목표 (없으면 NULL)',
  `shoulder_tilt_deg` DECIMAL(4,1) NULL COMMENT '어깨 기울기(도). 못 쟀으면 NULL',
  `pelvis_tilt_deg` DECIMAL(4,1) NULL COMMENT '골반 기울기(도)',
  `neck_forward_deg` DECIMAL(4,1) NULL COMMENT '목 전방 기울기(도). 측면 사진이 있을 때만',
  `shoulder_hip_ratio` DECIMAL(4,2) NULL COMMENT '어깨너비÷골반너비',
  `torso_leg_ratio` DECIMAL(4,2) NULL COMMENT '상체÷하체 길이',
  `unavailable_json` JSON NULL COMMENT '못 잰 항목과 사유 [{"key":"neck_forward","reason":"SIDE_PHOTO_MISSING"}]',
  `balance_score` TINYINT NULL COMMENT '균형 점수. 산식이 검증되기 전에는 항상 NULL(0점이 아님)',
  `measurement_version` VARCHAR(20) NULL COMMENT '측정·판정 기준 버전. 다르면 수치를 직접 비교하지 않는다',
  `body_type` VARCHAR(10) NULL COMMENT '골격 비율 기준 체형',
  `judgements_json` JSON NULL COMMENT '항목별 판정 [{item,label,value,unit,level,reason}]. 같은 수치도 기준 버전에 따라 달라지므로 계산해 저장',
  `priority_parts_json` JSON NULL COMMENT '집중 부위 1~3개 [{part,label}] (AI 소견)',
  `comparison_summary` VARCHAR(100) NULL COMMENT '목표 비교 한 문장 요약 (AI 소견)',
  `comparison_detail` VARCHAR(500) NULL COMMENT '목표 비교 두세 문장 설명 (AI 소견)',
  `pending_key` TINYINT GENERATED ALWAYS AS (IF(status = 'pending', 1, NULL)) STORED COMMENT '계산 컬럼. 사용자당 pending 1건만 허용하는 데 쓴다',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '접수 시각',
  `completed_at` DATETIME NULL COMMENT '완료·실패 시각',
  PRIMARY KEY (`analysis_id`),
  UNIQUE KEY `uq_analysis_one_pending` (`user_id`, `pending_key`),
  KEY `idx_analysis_user` (`user_id`, `created_at`),
  KEY `idx_analysis_pending` (`status`, `created_at`),
  CONSTRAINT `fk_body_analyses_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_body_analyses_photo_id` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`photo_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_body_analyses_side_photo_id` FOREIGN KEY (`side_photo_id`) REFERENCES `photos` (`photo_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_body_analyses_goal_body_id` FOREIGN KEY (`goal_body_id`) REFERENCES `goal_bodies` (`goal_body_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_body_analyses_source` CHECK (`source` IN ('photo', 'text')),
  CONSTRAINT `ck_body_analyses_status` CHECK (`status` IN ('pending', 'done', 'failed')),
  CONSTRAINT `ck_body_analyses_error_code` CHECK (`error_code` IN ('IMAGE_BLURRY', 'NO_PERSON', 'MULTIPLE_PEOPLE', 'NOT_FULL_BODY', 'NOT_FRONTAL', 'AI_FAILED', 'AI_TIMEOUT')),
  CONSTRAINT `ck_body_analyses_body_type` CHECK (`body_type` IN ('역삼각형', '직사각형', '사다리꼴'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='체형 분석';

-- 운동 종목 · MVP
CREATE TABLE `exercises` (
  `exercise_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '운동 ID',
  `name` VARCHAR(50) NOT NULL COMMENT '이름',
  `name_nospace` VARCHAR(50) GENERATED ALWAYS AS (REPLACE(name, ' ', '')) STORED COMMENT '계산 컬럼. 이름 검색(q)에서 공백을 무시하는 데 쓴다',
  `target_part` VARCHAR(10) NOT NULL COMMENT '주 운동 부위',
  `equipment` VARCHAR(10) NOT NULL COMMENT '기구',
  `difficulty` TINYINT NOT NULL COMMENT '난이도 1(쉬움)~5',
  `description` TEXT NULL COMMENT '동작 설명',
  `media_url` VARCHAR(500) NULL COMMENT '시범 영상 URL',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '0이면 목록·루틴에서 제외',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록 시각',
  PRIMARY KEY (`exercise_id`),
  UNIQUE KEY `uq_exercises_name` (`name`),
  KEY `idx_exercise_part` (`target_part`, `difficulty`),
  KEY `idx_exercise_search` (`name_nospace`),
  CONSTRAINT `ck_exercises_target_part` CHECK (`target_part` IN ('chest', 'back', 'leg', 'shoulder', 'arm', 'core')),
  CONSTRAINT `ck_exercises_equipment` CHECK (`equipment` IN ('barbell', 'dumbbell', 'machine', 'bodyweight')),
  CONSTRAINT `ck_exercise_difficulty` CHECK (difficulty BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='운동 종목';

-- 경력별 권장 세트 · MVP
CREATE TABLE `exercise_prescriptions` (
  `exercise_id` BIGINT NOT NULL COMMENT '운동',
  `experience_level` VARCHAR(10) NOT NULL COMMENT '경력',
  `min_sets` TINYINT NOT NULL COMMENT '권장 최소 세트',
  `max_sets` TINYINT NOT NULL COMMENT '권장 최대 세트',
  PRIMARY KEY (`exercise_id`, `experience_level`),
  CONSTRAINT `fk_exercise_prescriptions_exercise_id` FOREIGN KEY (`exercise_id`) REFERENCES `exercises` (`exercise_id`) ON DELETE CASCADE,
  CONSTRAINT `ck_exercise_prescriptions_experience_level` CHECK (`experience_level` IN ('under3m', 'under1y', 'over1y')),
  CONSTRAINT `ck_presc_range` CHECK (min_sets >= 1 AND min_sets <= max_sets)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='경력별 권장 세트';

-- 루틴 · MVP
CREATE TABLE `routines` (
  `routine_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `analysis_id` BIGINT NOT NULL COMMENT '근거가 된 분석',
  `scheduled_date` DATE NOT NULL COMMENT '수행 예정일',
  `title` VARCHAR(50) NOT NULL COMMENT '제목 (예: 어깨 · 등 집중)',
  `target_part` VARCHAR(10) NOT NULL COMMENT '주 부위',
  `estimated_minutes` SMALLINT NOT NULL COMMENT '예상 소요 시간(분)',
  `status` VARCHAR(10) NOT NULL DEFAULT 'planned' COMMENT '상태',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  PRIMARY KEY (`routine_id`),
  UNIQUE KEY `uq_routine_day` (`user_id`, `scheduled_date`),
  KEY `idx_routine_status` (`user_id`, `status`, `scheduled_date`),
  CONSTRAINT `fk_routines_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_routines_analysis_id` FOREIGN KEY (`analysis_id`) REFERENCES `body_analyses` (`analysis_id`),
  CONSTRAINT `ck_routines_target_part` CHECK (`target_part` IN ('chest', 'back', 'leg', 'shoulder', 'arm', 'core')),
  CONSTRAINT `ck_routines_status` CHECK (`status` IN ('planned', 'done', 'skipped'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='루틴';

-- 루틴 종목 · MVP
CREATE TABLE `routine_items` (
  `item_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '루틴 종목 ID',
  `routine_id` BIGINT NOT NULL COMMENT '루틴',
  `exercise_id` BIGINT NOT NULL COMMENT '운동',
  `order_no` TINYINT NOT NULL COMMENT '수행 순서 (1부터)',
  `target_sets` TINYINT NOT NULL COMMENT '목표 세트',
  `target_reps` TINYINT NOT NULL COMMENT '목표 횟수',
  `target_weight_kg` DECIMAL(5,1) NULL COMMENT '목표 무게. 맨몸 운동이면 NULL',
  `reason` VARCHAR(200) NULL COMMENT '이 종목을 넣은 이유',
  PRIMARY KEY (`item_id`),
  UNIQUE KEY `uq_item_order` (`routine_id`, `order_no`),
  UNIQUE KEY `uq_item_exercise` (`routine_id`, `exercise_id`),
  CONSTRAINT `fk_routine_items_routine_id` FOREIGN KEY (`routine_id`) REFERENCES `routines` (`routine_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_routine_items_exercise_id` FOREIGN KEY (`exercise_id`) REFERENCES `exercises` (`exercise_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='루틴 종목';

-- 운동 기록 · MVP
CREATE TABLE `workout_logs` (
  `log_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '운동 기록 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `exercise_id` BIGINT NOT NULL COMMENT '종목',
  `routine_id` BIGINT NULL COMMENT '루틴에서 시작했으면 루틴. 자유 운동이면 NULL',
  `status` VARCHAR(12) NOT NULL DEFAULT 'in_progress' COMMENT '진행 중 / 종료 / 6시간 초과 자동 중단',
  `workout_date` DATE NOT NULL COMMENT '시작 시각의 KST 날짜. 자정을 넘겨도 시작한 날',
  `started_at` DATETIME NOT NULL COMMENT '서버가 기록한 시작 시각. 앱을 나갔다 오면 지금−started_at으로 경과 시간을 복구',
  `completed_at` DATETIME NULL COMMENT '종료 시각. 진행 중이면 NULL',
  `duration_sec` INT NULL COMMENT '소요 시간(초). 진행 중이면 NULL',
  `memo` VARCHAR(500) NULL COMMENT '메모',
  `active_exercise_id` BIGINT GENERATED ALWAYS AS (IF(status = 'in_progress', exercise_id, NULL)) STORED COMMENT '계산 컬럼. 같은 종목의 진행 중 기록을 1개로 제한하는 데 쓴다',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  PRIMARY KEY (`log_id`),
  UNIQUE KEY `uq_log_one_active` (`user_id`, `active_exercise_id`),
  KEY `idx_log_date` (`user_id`, `workout_date`),
  KEY `idx_log_status` (`status`, `started_at`),
  KEY `idx_log_routine` (`routine_id`, `exercise_id`, `status`),
  CONSTRAINT `fk_workout_logs_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_workout_logs_exercise_id` FOREIGN KEY (`exercise_id`) REFERENCES `exercises` (`exercise_id`),
  CONSTRAINT `fk_workout_logs_routine_id` FOREIGN KEY (`routine_id`) REFERENCES `routines` (`routine_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_workout_logs_status` CHECK (`status` IN ('in_progress', 'completed', 'aborted'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='운동 기록';

-- 운동 세트 · MVP
CREATE TABLE `workout_sets` (
  `set_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '세트 ID',
  `log_id` BIGINT NOT NULL COMMENT '운동 기록',
  `client_set_id` CHAR(36) NOT NULL COMMENT '앱이 세트마다 만든 UUID',
  `set_no` TINYINT NOT NULL COMMENT '세트 번호 (1부터). 삭제해도 다시 매기지 않는다',
  `weight_kg` DECIMAL(5,1) NOT NULL COMMENT '무게. 맨몸 운동은 0',
  `reps` SMALLINT NOT NULL COMMENT '횟수',
  `rest_sec` SMALLINT NULL COMMENT '그 세트 뒤 실제로 쉰 시간(초)',
  `is_done` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '완료 여부',
  `version` INT NOT NULL DEFAULT 1 COMMENT '수정할 때마다 +1. 요청의 값과 다르면 VERSION_CONFLICT',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',
  PRIMARY KEY (`set_id`),
  UNIQUE KEY `uq_set_client` (`log_id`, `client_set_id`),
  UNIQUE KEY `uq_set_no` (`log_id`, `set_no`),
  CONSTRAINT `fk_workout_sets_log_id` FOREIGN KEY (`log_id`) REFERENCES `workout_logs` (`log_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='운동 세트';
