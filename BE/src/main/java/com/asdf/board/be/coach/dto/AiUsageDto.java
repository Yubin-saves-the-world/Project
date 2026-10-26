package com.asdf.board.be.coach.dto;

import java.time.OffsetDateTime;

public record AiUsageDto(
        Integer used,
        Integer limit,
        Integer remaining,
        OffsetDateTime resetAt
) {
}
