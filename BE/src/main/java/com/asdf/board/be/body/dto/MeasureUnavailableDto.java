package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record MeasureUnavailableDto(
        @Schema(description = "측정하지 못한 항목") String key,
        @Schema(description = "사유: 측면 사진 없음 / 신체가 가려짐 / 관절 인식 신뢰도 낮음 / 판정 기준 미검증") String reason
) {
}
