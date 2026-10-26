package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.LocalDate;

public record VolumePointDto(
        @Schema(description = "날짜") LocalDate date,
        @Schema(description = "그날 총 볼륨") BigDecimal volumeKg
) {
}
