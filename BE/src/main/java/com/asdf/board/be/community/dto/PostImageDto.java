package com.asdf.board.be.community.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record PostImageDto(
        @Schema(description = "이미지 ID") Long imageId,
        @Schema(description = "이미지 URL") String url
) {
}
