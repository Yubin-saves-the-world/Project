package com.asdf.board.be.community.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record AuthorDto(
        @Schema(description = "작성자 ID") Long userId,
        @Schema(description = "닉네임") String nickname
) {
}
