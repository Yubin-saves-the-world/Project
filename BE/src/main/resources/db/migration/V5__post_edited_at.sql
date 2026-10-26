-- V5 · 게시글 본문 수정 시각. updated_at은 조회수·좋아요 수 갱신에도 바뀌므로 "수정함" 판단에 쓸 수 없다.
ALTER TABLE `posts`
  ADD COLUMN `edited_at` DATETIME NULL COMMENT '본문·이미지를 수정한 시각. 수정한 적 없으면 NULL' AFTER `hidden_at`;
