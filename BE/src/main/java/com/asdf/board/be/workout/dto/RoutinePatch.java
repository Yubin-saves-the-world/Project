package com.asdf.board.be.workout.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;

public record RoutinePatch(
        @Schema(description = "skipped 건너뛰기 / planned 건너뛴 루틴 되돌리기(오늘 이후만). 완료(done)는 서버가 운동 기록으로 자동 처리") @NotNull(message = "status을(를) 입력해 주세요.") RoutinePatchStatus status
) {
}
