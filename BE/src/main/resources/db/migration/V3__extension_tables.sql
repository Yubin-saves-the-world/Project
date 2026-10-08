-- V3 · 확장 테이블
-- 이 파일은 api/gen/model.py 에서 생성한다. 직접 고치지 말고 model.py 를 고친 뒤 `python api/gen/build_all.py` 를 다시 실행한다.
-- 대상: MySQL 8.0 이상 (CHECK 제약과 계산 컬럼 사용). 문자셋 utf8mb4, 시간은 모두 KST.

-- 제휴사 · 확장
CREATE TABLE `partners` (
  `partner_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '제휴사 ID',
  `name` VARCHAR(50) NOT NULL COMMENT '이름',
  `contract_start` DATE NOT NULL COMMENT '계약 시작',
  `contract_end` DATE NOT NULL COMMENT '계약 종료',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록 시각',
  PRIMARY KEY (`partner_id`),
  CONSTRAINT `ck_partner_period` CHECK (contract_start <= contract_end)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='제휴사';

-- 제휴 상품 · 확장
CREATE TABLE `products` (
  `product_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '상품 ID',
  `partner_id` BIGINT NOT NULL COMMENT '제휴사',
  `category` VARCHAR(12) NOT NULL COMMENT '분류',
  `name` VARCHAR(100) NOT NULL COMMENT '상품명',
  `kcal` SMALLINT NULL COMMENT '칼로리',
  `carb_g` SMALLINT NULL COMMENT '탄수화물(g)',
  `protein_g` SMALLINT NULL COMMENT '단백질(g)',
  `fat_g` SMALLINT NULL COMMENT '지방(g)',
  `price` INT NULL COMMENT '가격(원). 모르면 NULL',
  `link_url` VARCHAR(500) NOT NULL COMMENT '판매 페이지',
  `display_from` DATE NOT NULL COMMENT '노출 시작',
  `display_to` DATE NOT NULL COMMENT '노출 종료',
  `is_ad_labeled` TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'true면 화면에 "광고·제휴"를 표시해야 한다',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록 시각',
  PRIMARY KEY (`product_id`),
  KEY `idx_product_display` (`category`, `display_from`, `display_to`),
  CONSTRAINT `fk_products_partner_id` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`partner_id`),
  CONSTRAINT `ck_products_category` CHECK (`category` IN ('food', 'supplement', 'equipment'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='제휴 상품';

-- 할인권 종류 · 확장
CREATE TABLE `coupons` (
  `coupon_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '할인권 ID',
  `partner_id` BIGINT NOT NULL COMMENT '제휴사',
  `title` VARCHAR(50) NOT NULL COMMENT '이름',
  `discount_desc` VARCHAR(100) NOT NULL COMMENT '할인 내용',
  `valid_days` SMALLINT NOT NULL COMMENT '발급 후 유효 일수',
  PRIMARY KEY (`coupon_id`),
  CONSTRAINT `fk_coupons_partner_id` FOREIGN KEY (`partner_id`) REFERENCES `partners` (`partner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='할인권 종류';

-- 미션 · 확장
CREATE TABLE `missions` (
  `mission_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '미션 ID',
  `title` VARCHAR(50) NOT NULL COMMENT '제목',
  `condition_json` JSON NOT NULL COMMENT '달성 조건 예: {"type":"workout_days","count":3}',
  `period_days` SMALLINT NOT NULL COMMENT '기간(일)',
  `coupon_id` BIGINT NULL COMMENT '달성 보상 할인권',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1이면 현재 미션 후보. 현재 미션은 is_active=1인 것 중 가장 최근에 등록한 1개',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록 시각',
  PRIMARY KEY (`mission_id`),
  CONSTRAINT `fk_missions_coupon_id` FOREIGN KEY (`coupon_id`) REFERENCES `coupons` (`coupon_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='미션';

-- 참여 중인 미션 · 확장
CREATE TABLE `user_missions` (
  `user_mission_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `mission_id` BIGINT NOT NULL COMMENT '미션',
  `started_at` DATETIME NOT NULL COMMENT '시작 시각',
  `ends_at` DATETIME NOT NULL COMMENT '종료 시각 (시작 + period_days)',
  `progress_count` INT NOT NULL DEFAULT 0 COMMENT '현재 달성 횟수',
  `completed_at` DATETIME NULL COMMENT '달성 시각. 달성하면 할인권을 자동 발급한다',
  PRIMARY KEY (`user_mission_id`),
  UNIQUE KEY `uq_user_mission` (`user_id`, `mission_id`, `started_at`),
  CONSTRAINT `fk_user_missions_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_user_missions_mission_id` FOREIGN KEY (`mission_id`) REFERENCES `missions` (`mission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='참여 중인 미션';

-- 내 할인권 · 확장
CREATE TABLE `user_coupons` (
  `user_coupon_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `coupon_id` BIGINT NOT NULL COMMENT '할인권 종류',
  `user_mission_id` BIGINT NULL COMMENT '어느 미션 달성으로 받았는지',
  `status` VARCHAR(10) NOT NULL DEFAULT 'available' COMMENT '상태',
  `valid_until` DATE NOT NULL COMMENT '유효기간 마지막 날',
  `issued_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '발급 시각',
  `used_at` DATETIME NULL COMMENT '사용 시각',
  PRIMARY KEY (`user_coupon_id`),
  KEY `idx_user_coupon` (`user_id`, `status`, `valid_until`),
  CONSTRAINT `fk_user_coupons_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_user_coupons_coupon_id` FOREIGN KEY (`coupon_id`) REFERENCES `coupons` (`coupon_id`),
  CONSTRAINT `fk_user_coupons_user_mission_id` FOREIGN KEY (`user_mission_id`) REFERENCES `user_missions` (`user_mission_id`) ON DELETE SET NULL,
  CONSTRAINT `ck_user_coupons_status` CHECK (`status` IN ('available', 'used', 'expired'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='내 할인권';

-- 알림 설정 · 확장
CREATE TABLE `notification_settings` (
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `type` VARCHAR(12) NOT NULL COMMENT '알림 종류',
  `enabled` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '켜짐',
  `notify_time` TIME NULL COMMENT '알림 시각. streak_risk는 서버 고정이라 NULL',
  PRIMARY KEY (`user_id`, `type`),
  CONSTRAINT `fk_notification_settings_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_notification_settings_type` CHECK (`type` IN ('workout', 'diet', 'streak_risk'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='알림 설정';

-- 푸시 기기 토큰 · 확장
CREATE TABLE `device_tokens` (
  `token_id` BIGINT NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `user_id` BIGINT NOT NULL COMMENT '회원',
  `fcm_token` VARCHAR(255) NOT NULL COMMENT 'FCM 등록 토큰',
  `platform` VARCHAR(10) NOT NULL COMMENT '플랫폼',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '등록 시각',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '갱신 시각',
  PRIMARY KEY (`token_id`),
  UNIQUE KEY `uq_device_tokens_fcm_token` (`fcm_token`),
  UNIQUE KEY `uq_device_platform` (`user_id`, `platform`),
  CONSTRAINT `fk_device_tokens_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `ck_device_tokens_platform` CHECK (`platform` IN ('android', 'ios'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='푸시 기기 토큰';

-- 이전 단계 테이블에 추가되는 컬럼
ALTER TABLE `diet_items`
  ADD COLUMN `product_id` BIGINT NULL COMMENT '연결된 제휴 상품. 확장 단계에서 추가',
  ADD CONSTRAINT `fk_diet_items_product_id` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE SET NULL;
