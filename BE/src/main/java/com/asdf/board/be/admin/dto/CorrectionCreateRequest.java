package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CorrectionCreateRequest(
        @Schema(description = "대상 항목") @NotNull(message = "target_issue을(를) 입력해 주세요.") com.asdf.board.be.correction.entity.CorrectionExercise.TargetIssue targetIssue,
        @Schema(description = "이름") @NotBlank(message = "name을(를) 입력해 주세요.") @Size(max = 50, message = "name 길이를 확인해 주세요.") String name,
        @Schema(description = "방법") @NotBlank(message = "method을(를) 입력해 주세요.") @Size(max = 1000, message = "method 길이를 확인해 주세요.") String method,
        @Schema(description = "시간 또는 횟수") @NotBlank(message = "duration_or_reps을(를) 입력해 주세요.") @Size(max = 30, message = "duration_or_reps 길이를 확인해 주세요.") String durationOrReps,
        @Schema(description = "시범 영상") @Size(max = 500, message = "media_url 길이를 확인해 주세요.") String mediaUrl
) {
}
