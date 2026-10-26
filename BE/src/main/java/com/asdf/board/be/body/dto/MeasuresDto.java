package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.util.List;

public record MeasuresDto(
        @Schema(description = "어깨 좌우 높이차(기울기, 도). 정면 사진 기준") BigDecimal shoulderTiltDeg,
        @Schema(description = "골반 좌우 기울기(도). 정면 사진 기준") BigDecimal pelvisTiltDeg,
        @Schema(description = "목 전방 기울기(도). 측면 사진이 있을 때만 값이 있고 없으면 null") BigDecimal neckForwardDeg,
        @Schema(description = "어깨너비÷골반너비. 계산하지 못하면 null") BigDecimal shoulderHipRatio,
        @Schema(description = "상체길이÷하체길이. 계산하지 못하면 null") BigDecimal torsoLegRatio,
        @Schema(description = "null인 항목과 사유. 모두 계산됐으면 빈 배열") List<MeasureUnavailableDto> unavailable
) {
}
