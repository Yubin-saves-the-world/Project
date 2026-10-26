package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record DeletedCountDto(
        @Schema(description = "삭제된 사진 수") Integer deletedCount,
        @Schema(description = "목표 체형에 필요해서 건너뛴 사진 수") Integer skippedCount
) {
}
