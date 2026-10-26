package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record AnalysisPageDto(
        @Schema(description = "목록") List<AnalysisSummaryDto> items,
        @Schema(description = "현재 페이지 (1부터)") Integer page,
        @Schema(description = "페이지 크기") Integer pageSize,
        @Schema(description = "전체 개수") Integer total
) {
}
