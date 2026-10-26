package com.asdf.board.be.coach.dto;

import java.time.OffsetDateTime;

public record ChatMessageDto(
        Long messageId,
        String role,
        String content,
        OffsetDateTime createdAt,
        RoutineSuggestionDto suggestion
) {
}
