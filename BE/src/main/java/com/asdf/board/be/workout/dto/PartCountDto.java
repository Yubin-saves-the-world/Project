package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record PartCountDto(
        @Schema(description = "부위") String targetPart,
        @Schema(description = "종료된 기록 수") Integer count
) {
}
