-- V2 · 2차 테이블
-- 이 파일은 api/gen/model.py 에서 생성한다. 직접 고치지 말고 model.py 를 고친 뒤 `python api/gen/build_all.py` 를 다시 실행한다.
-- 대상: MySQL 8.0 이상 (CHECK 제약과 계산 컬럼 사용). 문자셋 utf8mb4, 시간은 모두 KST.

-- 알레르기 · 제외 음식 · 2차
CREATE TABLE `user_allergies` (
  `allergy_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `item` VARCHAR(50) NOT NULL COMMENT '알레르기 또는 먹지 않는 음식 (앞뒤 공백 제거)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록 시각',
  PRIMARY KEY (`allergy_id`),
  UNIQUE KEY `uq_allergy_item` (`user_id`, `item`),
  CONSTRAINT `fk_user_allergies_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='알레르기 · 제외 음식';

-- 비밀번호 재설정 토큰 · 2차
CREATE TABLE `password_reset_tokens` (
  `token_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `token_hash` CHAR(64) NOT NULL COMMENT '토큰의 SHA-256 해시(16진수)',
  `expires_at` DATETIME NOT NULL COMMENT '만료 시각 (발급 + 30분)',
  `used_at` DATETIME NULL COMMENT '사용 시각. 값이 있으면 다시 쓸 수 없다',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '발급 시각',
  PRIMARY KEY (`token_id`),
  UNIQUE KEY `uq_password_reset_tokens_token_hash` (`token_hash`),
  KEY `idx_reset_user` (`user_id`, `created_at`),
  CONSTRAINT `fk_password_reset_tokens_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='비밀번호 재설정 토큰';

-- 교정 운동 · 2차
CREATE TABLE `correction_exercises` (
  `correction_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '교정 운동 ID',
  `target_issue` VARCHAR(20) NOT NULL COMMENT '대상 판정 항목',
  `name` VARCHAR(50) NOT NULL COMMENT '이름',
  `method` TEXT NOT NULL COMMENT '방법',
  `duration_or_reps` VARCHAR(30) NOT NULL COMMENT '수행 시간 또는 횟수 (예: 30초 × 3회)',
  `media_url` VARCHAR(500) NULL COMMENT '시범 영상',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '0이면 노출하지 않음',
  PRIMARY KEY (`correction_id`),
  KEY `idx_correction_issue` (`target_issue`, `is_active`),
  CONSTRAINT `ck_correction_exercises_target_issue` CHECK (`target_issue` IN ('shoulder_tilt', 'pelvis_tilt', 'neck_forward'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='교정 운동';

-- 식단 · 2차
CREATE TABLE `diet_plans` (
  `plan_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '식단 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `analysis_id` BIGINT NOT NULL COMMENT '근거가 된 분석',
  `plan_date` DATE NOT NULL COMMENT '날짜',
  `target_kcal` SMALLINT NOT NULL COMMENT '목표 칼로리',
  `carb_g` SMALLINT NOT NULL COMMENT '탄수화물(g)',
  `protein_g` SMALLINT NOT NULL COMMENT '단백질(g)',
  `fat_g` SMALLINT NOT NULL COMMENT '지방(g)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  PRIMARY KEY (`plan_id`),
  UNIQUE KEY `uq_diet_day` (`user_id`, `plan_date`),
  CONSTRAINT `fk_diet_plans_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_diet_plans_analysis_id` FOREIGN KEY (`analysis_id`) REFERENCES `body_analyses` (`analysis_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='식단';

-- 식단 끼니 · 2차
CREATE TABLE `diet_meals` (
  `meal_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '끼니 ID',
  `plan_id` BIGINT NOT NULL COMMENT '식단',
  `meal_type` VARCHAR(10) NOT NULL COMMENT '끼니',
  `total_kcal` SMALLINT NOT NULL COMMENT '끼니 칼로리 합',
  PRIMARY KEY (`meal_id`),
  UNIQUE KEY `uq_meal_type` (`plan_id`, `meal_type`),
  CONSTRAINT `fk_diet_meals_plan_id` FOREIGN KEY (`plan_id`) REFERENCES `diet_plans` (`plan_id`) ON DELETE CASCADE,
  CONSTRAINT `ck_diet_meals_meal_type` CHECK (`meal_type` IN ('breakfast', 'lunch', 'dinner', 'snack'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='식단 끼니';

-- 식단 음식 · 2차
CREATE TABLE `diet_items` (
  `diet_item_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `meal_id` BIGINT NOT NULL COMMENT '끼니',
  `food_name` VARCHAR(50) NOT NULL COMMENT '음식 이름',
  `amount` VARCHAR(30) NOT NULL COMMENT '양 (예: 200g, 1개)',
  `kcal` SMALLINT NOT NULL COMMENT '칼로리',
  PRIMARY KEY (`diet_item_id`),
  CONSTRAINT `fk_diet_items_meal_id` FOREIGN KEY (`meal_id`) REFERENCES `diet_meals` (`meal_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='식단 음식';

-- AI 코치 대화 · 2차
CREATE TABLE `ai_chat_messages` (
  `message_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '메시지 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `role` VARCHAR(10) NOT NULL COMMENT '발화자',
  `content` TEXT NOT NULL COMMENT '내용 (질문은 500자 이내)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '시각',
  PRIMARY KEY (`message_id`),
  KEY `idx_chat_user` (`user_id`, `created_at`),
  KEY `idx_chat_quota` (`user_id`, `role`, `created_at`),
  CONSTRAINT `fk_ai_chat_messages_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_ai_chat_messages_role` CHECK (`role` IN ('user', 'assistant'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI 코치 대화';

-- 루틴 수정 제안 · 2차
CREATE TABLE `routine_suggestions` (
  `suggestion_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '제안 ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `message_id` BIGINT NOT NULL COMMENT '제안이 담긴 AI 답변',
  `summary` VARCHAR(100) NOT NULL COMMENT '한 줄 요약',
  `changes_json` JSON NOT NULL COMMENT '변경 내용 [{action,routine_item_id,exercise_id,target_sets,target_reps}]',
  `status` VARCHAR(10) NOT NULL DEFAULT 'pending' COMMENT '처리 상태',
  `expires_at` DATETIME NOT NULL COMMENT '만료 시각 (생성 + 24시간)',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 시각',
  `handled_at` DATETIME NULL COMMENT '적용·거절 시각',
  PRIMARY KEY (`suggestion_id`),
  KEY `idx_suggestion_user` (`user_id`, `status`, `expires_at`),
  CONSTRAINT `fk_routine_suggestions_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_routine_suggestions_message_id` FOREIGN KEY (`message_id`) REFERENCES `ai_chat_messages` (`message_id`),
  CONSTRAINT `ck_routine_suggestions_status` CHECK (`status` IN ('pending', 'applied', 'dismissed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='루틴 수정 제안';

-- 게시글 · 2차
CREATE TABLE `posts` (
  `post_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '게시글 ID',
  `user_id` BIGINT NOT NULL COMMENT '작성자 (탈퇴한 회원이면 화면에서 "탈퇴한 사용자")',
  `category` VARCHAR(10) NOT NULL COMMENT '공지 / 운동 정보 / 인증 / 질문. notice는 관리자만',
  `title` VARCHAR(50) NOT NULL COMMENT '제목',
  `content` VARCHAR(2000) NOT NULL COMMENT '본문',
  `is_pinned` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '상단 고정(공지)',
  `view_count` INT NOT NULL DEFAULT 0 COMMENT '조회 수',
  `like_count` INT NOT NULL DEFAULT 0 COMMENT '좋아요 수 (좋아요 처리와 같은 트랜잭션에서 갱신)',
  `comment_count` INT NOT NULL DEFAULT 0 COMMENT '댓글 수',
  `hidden_at` DATETIME NULL COMMENT '신고 3건 누적 등으로 숨긴 시각. 값이 있으면 목록에서 제외',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '작성 시각',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 시각',
  PRIMARY KEY (`post_id`),
  KEY `idx_post_list` (`category`, `is_pinned`, `created_at`),
  KEY `idx_post_user` (`user_id`, `created_at`),
  CONSTRAINT `fk_posts_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_posts_category` CHECK (`category` IN ('notice', 'info', 'proof', 'question'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='게시글';

-- 게시글 이미지 · 2차
CREATE TABLE `post_images` (
  `image_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '이미지 ID',
  `post_id` BIGINT NOT NULL COMMENT '게시글',
  `storage_key` VARCHAR(255) NOT NULL COMMENT 'S3 객체 키',
  `order_no` TINYINT NOT NULL COMMENT '순서 (1~4)',
  PRIMARY KEY (`image_id`),
  UNIQUE KEY `uq_post_images_storage_key` (`storage_key`),
  UNIQUE KEY `uq_image_order` (`post_id`, `order_no`),
  CONSTRAINT `fk_post_images_post_id` FOREIGN KEY (`post_id`) REFERENCES `posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `ck_image_order` CHECK (order_no BETWEEN 1 AND 4)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='게시글 이미지';

-- 댓글 · 2차
CREATE TABLE `comments` (
  `comment_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '댓글 ID',
  `post_id` BIGINT NOT NULL COMMENT '게시글',
  `user_id` BIGINT NOT NULL COMMENT '작성자',
  `parent_id` BIGINT NULL COMMENT '대댓글이면 부모 댓글. 부모의 부모로는 붙이지 않는다',
  `content` VARCHAR(500) NOT NULL COMMENT '내용. 삭제된 자리 표시이면 빈 문자열',
  `is_deleted` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'true면 "삭제된 댓글입니다."로 보여준다',
  `hidden_at` DATETIME NULL COMMENT '신고 누적으로 숨긴 시각',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '작성 시각',
  PRIMARY KEY (`comment_id`),
  KEY `idx_comment_post` (`post_id`, `created_at`),
  CONSTRAINT `fk_comments_post_id` FOREIGN KEY (`post_id`) REFERENCES `posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_comments_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_comments_parent_id` FOREIGN KEY (`parent_id`) REFERENCES `comments` (`comment_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='댓글';

-- 게시글 좋아요 · 2차
CREATE TABLE `post_likes` (
  `post_id` BIGINT NOT NULL COMMENT '게시글',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '시각',
  PRIMARY KEY (`post_id`, `user_id`),
  CONSTRAINT `fk_post_likes_post_id` FOREIGN KEY (`post_id`) REFERENCES `posts` (`post_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_post_likes_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='게시글 좋아요';

-- 신고 · 2차
CREATE TABLE `reports` (
  `report_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '신고 ID',
  `reporter_id` BIGINT NOT NULL COMMENT '신고자',
  `target_type` VARCHAR(10) NOT NULL COMMENT '대상 종류',
  `target_id` BIGINT NOT NULL COMMENT '대상 ID (종류에 따라 posts 또는 comments). 두 테이블을 가리키므로 FK를 걸지 않는다',
  `reason` VARCHAR(15) NOT NULL COMMENT '사유',
  `detail` VARCHAR(200) NULL COMMENT '상세 설명',
  `status` VARCHAR(10) NOT NULL DEFAULT 'pending' COMMENT '처리 상태',
  `handled_by` BIGINT NULL COMMENT '처리한 관리자',
  `handled_at` DATETIME NULL COMMENT '처리 시각',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '신고 시각',
  PRIMARY KEY (`report_id`),
  UNIQUE KEY `uq_report_once` (`reporter_id`, `target_type`, `target_id`),
  KEY `idx_report_target` (`target_type`, `target_id`, `status`),
  KEY `idx_report_status` (`status`, `created_at`),
  CONSTRAINT `fk_reports_reporter_id` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_reports_handled_by` FOREIGN KEY (`handled_by`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_reports_target_type` CHECK (`target_type` IN ('post', 'comment')),
  CONSTRAINT `ck_reports_reason` CHECK (`reason` IN ('spam', 'abuse', 'inappropriate', 'other')),
  CONSTRAINT `ck_reports_status` CHECK (`status` IN ('pending', 'resolved', 'rejected'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='신고';

-- 차단 · 2차
CREATE TABLE `blocks` (
  `blocker_id` BIGINT NOT NULL COMMENT '차단한 사람',
  `blocked_id` BIGINT NOT NULL COMMENT '차단당한 사람',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '차단 시각',
  PRIMARY KEY (`blocker_id`, `blocked_id`),
  CONSTRAINT `fk_blocks_blocker_id` FOREIGN KEY (`blocker_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_blocks_blocked_id` FOREIGN KEY (`blocked_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_block_self` CHECK (blocker_id <> blocked_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='차단';

-- 이전 단계 테이블에 추가되는 컬럼
ALTER TABLE `users`
  ADD COLUMN `auth_provider` VARCHAR(10) NOT NULL DEFAULT 'email' COMMENT '가입 방식',
  ADD COLUMN `google_sub` VARCHAR(64) NULL COMMENT '구글 계정의 고유 ID(sub). 이메일이 바뀌어도 같은 사람을 찾는다',
  ADD COLUMN `kakao_id` BIGINT NULL COMMENT '카카오 회원번호(id). 이메일이 없거나 바뀌어도 같은 사람을 찾는다',
  ADD CONSTRAINT `ck_users_auth_provider` CHECK (`auth_provider` IN ('email', 'google', 'kakao')),
  ADD UNIQUE KEY `uq_users_google_sub` (`google_sub`),
  ADD UNIQUE KEY `uq_users_kakao_id` (`kakao_id`);

ALTER TABLE `body_analyses`
  ADD COLUMN `text_input` VARCHAR(500) NULL COMMENT '글 분석의 입력 문장',
  ADD COLUMN `text_summary` VARCHAR(500) NULL COMMENT '글 분석 요약';
