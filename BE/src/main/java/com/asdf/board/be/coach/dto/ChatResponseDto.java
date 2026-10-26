package com.asdf.board.be.coach.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record ChatResponseDto(
        @Schema(description = "저장된 내 질문") ChatMessageDto userMessage,
        @Schema(description = "AI 답변") ChatMessageDto reply,
        @Schema(description = "루틴 수정 제안. 없으면 null") RoutineSuggestionDto suggestion,
        @Schema(description = "오늘 남은 질문 횟수") Integer remainingToday
) {
}
