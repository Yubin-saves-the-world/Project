package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record BodyPartDto(
        @Schema(description = "부위 코드") String part,
        @Schema(description = "화면 표시 이름") String label
) {
}
