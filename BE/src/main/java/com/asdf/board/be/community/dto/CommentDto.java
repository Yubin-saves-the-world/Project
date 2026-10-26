package com.asdf.board.be.community.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record CommentDto(
        Long commentId,
        Long postId,
        @Schema(description = "대댓글이면 부모 댓글 ID, 아니면 null") Long parentId,
        AuthorDto author,
        @Schema(description = "내용. 삭제된 댓글에 대댓글이 있으면 \"삭제된 댓글입니다.\"") String content,
        @Schema(description = "삭제된 댓글 자리 표시 여부") Boolean isDeleted,
        @Schema(description = "내가 쓴 댓글인지") Boolean isMine,
        OffsetDateTime createdAt
) {
}
