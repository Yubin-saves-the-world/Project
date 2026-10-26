package com.asdf.board.be.correction.dto;

import io.swagger.v3.oas.annotations.media.Schema;

public record CorrectionExerciseDto(
        @Schema(description = "교정 운동 ID") Long correctionId,
        @Schema(description = "대상 항목") String targetIssue,
        @Schema(description = "이름") String name,
        @Schema(description = "수행 시간 또는 횟수") String durationOrReps,
        @Schema(description = "시범 영상. 없으면 null") String mediaUrl
) {
}
