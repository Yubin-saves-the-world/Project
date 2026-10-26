package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

public record AnalysisRequest(
        @Schema(description = "정면 사진 ID (type=current, side=front)") @NotNull(message = "photo_id을(를) 입력해 주세요.") Long photoId,
        @Schema(description = "측면 사진 ID (type=current, side=side). 없으면 목 전방 기울기는 계산하지 않음") Long sidePhotoId,
        @Schema(description = "목표 체형 ID. 있으면 목표와의 비교(goal_comparison)까지 수행") Long goalBodyId
) {
}
