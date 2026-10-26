-- V6 · 확장 단계 컬럼을 API 명세(openapi.yaml)의 길이에 맞춘다.
ALTER TABLE `missions` MODIFY COLUMN `title` VARCHAR(100) NOT NULL COMMENT '제목';
ALTER TABLE `coupons`
  MODIFY COLUMN `title` VARCHAR(100) NOT NULL COMMENT '이름',
  MODIFY COLUMN `discount_desc` VARCHAR(200) NOT NULL COMMENT '할인 내용';
-- FCM 토큰은 명세상 최대 4096자라 유니크 인덱스를 걸 수 없다. 해시(SHA-256 hex)에 유니크를 건다.
ALTER TABLE `device_tokens`
  DROP INDEX `uq_device_tokens_fcm_token`,
  MODIFY COLUMN `fcm_token` VARCHAR(4096) NOT NULL COMMENT 'FCM 등록 토큰',
  ADD COLUMN `token_hash` CHAR(64) NOT NULL COMMENT 'fcm_token의 SHA-256(hex). 중복 방지용' AFTER `fcm_token`,
  ADD UNIQUE KEY `uq_device_tokens_hash` (`token_hash`);
