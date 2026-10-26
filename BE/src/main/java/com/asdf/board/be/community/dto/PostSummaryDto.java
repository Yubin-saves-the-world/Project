package com.asdf.board.be.community.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record PostSummaryDto(
        @Schema(description = "게시글 ID") Long postId,
        @Schema(description = "공지 / 운동 정보 / 인증 / 질문") String category,
        @Schema(description = "제목") String title,
        @Schema(description = "본문 앞 100자") String contentPreview,
        @Schema(description = "작성자") AuthorDto author,
        @Schema(description = "첫 이미지 썸네일. 이미지가 없으면 null") String thumbnailUrl,
        @Schema(description = "좋아요 수") Integer likeCount,
        @Schema(description = "댓글 수") Integer commentCount,
        @Schema(description = "조회 수") Integer viewCount,
        @Schema(description = "상단 고정(공지) 여부") Boolean isPinned,
        @Schema(description = "작성 시각") OffsetDateTime createdAt
) {
}
