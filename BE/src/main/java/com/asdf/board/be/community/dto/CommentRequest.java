package com.asdf.board.be.community.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CommentRequest(
        @Schema(description = "내용") @NotBlank(message = "content을(를) 입력해 주세요.") @Size(min = 1, max = 500, message = "content 길이를 확인해 주세요.") String content,
        @Schema(description = "대댓글이면 부모 댓글 ID (댓글의 댓글까지만, 그 이상 깊이는 부모의 부모로 붙임)") Long parentId
) {
}
