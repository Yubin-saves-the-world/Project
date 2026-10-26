package com.asdf.board.be.correction.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record CorrectionListDto(
        @Schema(description = "기준이 된 최근 분석. 분석이 없으면 null") Long analysisId,
        @Schema(description = "교정 운동 (항목별 2~3개)") List<CorrectionExerciseDto> items
) {
}
