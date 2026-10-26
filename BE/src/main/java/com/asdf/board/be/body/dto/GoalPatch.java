package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;

public record GoalPatch(
        @Schema(description = "새 목표 사진 ID (등록 때와 같이 처리 후 삭제)") Long photoId,
        @Schema(description = "새 설명") @Size(min = 1, max = 200, message = "description 길이를 확인해 주세요.") String description
) {
}
