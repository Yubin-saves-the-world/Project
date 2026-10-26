package com.asdf.board.be.coach.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import java.util.List;

public record RoutineSuggestionDto(
        Long suggestionId,
        String summary,
        @Schema(description = "변경 내용") List<SuggestionChangeDto> changes,
        @Schema(description = "pending / applied / dismissed") String status,
        OffsetDateTime expiresAt
) {
}
