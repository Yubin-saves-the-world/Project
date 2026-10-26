package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;

public record CorrectionPatch(
        @Schema(description = "대상 항목") com.asdf.board.be.correction.entity.CorrectionExercise.TargetIssue targetIssue,
        @Schema(description = "이름") @Size(min = 1, max = 50, message = "name 길이를 확인해 주세요.") String name,
        @Schema(description = "방법") @Size(min = 1, max = 1000, message = "method 길이를 확인해 주세요.") String method,
        @Schema(description = "시간 또는 횟수") @Size(min = 1, max = 30, message = "duration_or_reps 길이를 확인해 주세요.") String durationOrReps,
        @Schema(description = "시범 영상") @Size(max = 500, message = "media_url 길이를 확인해 주세요.") String mediaUrl
) {
}
