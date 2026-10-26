package com.asdf.board.be.community.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import java.util.List;

public record PostDto(
        Long postId,
        String category,
        String title,
        String contentPreview,
        AuthorDto author,
        String thumbnailUrl,
        Integer likeCount,
        Integer commentCount,
        Integer viewCount,
        Boolean isPinned,
        OffsetDateTime createdAt,
        @Schema(description = "본문") String content,
        @Schema(description = "이미지 (최대 4장)") List<PostImageDto> images,
        @Schema(description = "내가 좋아요를 눌렀는지") Boolean likedByMe,
        @Schema(description = "내가 쓴 글인지") Boolean isMine,
        @Schema(description = "수정 시각. 수정 안 했으면 null") OffsetDateTime updatedAt
) {
}
