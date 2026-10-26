package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ExerciseCreateRequest(
        @Schema(description = "이름") @NotBlank(message = "name을(를) 입력해 주세요.") @Size(max = 50, message = "name 길이를 확인해 주세요.") String name,
        @Schema(description = "주 부위") @NotNull(message = "target_part을(를) 입력해 주세요.") com.asdf.board.be.global.enums.TargetPart targetPart,
        @Schema(description = "난이도") @NotNull(message = "difficulty을(를) 입력해 주세요.") @Min(value = 1, message = "difficulty 범위를 확인해 주세요.") @Max(value = 5, message = "difficulty 범위를 확인해 주세요.") Integer difficulty,
        @Schema(description = "기구") @NotNull(message = "equipment을(를) 입력해 주세요.") com.asdf.board.be.workout.entity.Exercise.Equipment equipment,
        @Schema(description = "권장 최소 세트") @NotNull(message = "min_sets을(를) 입력해 주세요.") @Min(value = 1, message = "min_sets 범위를 확인해 주세요.") @Max(value = 10, message = "min_sets 범위를 확인해 주세요.") Integer minSets,
        @Schema(description = "권장 최대 세트") @NotNull(message = "max_sets을(를) 입력해 주세요.") @Min(value = 1, message = "max_sets 범위를 확인해 주세요.") @Max(value = 10, message = "max_sets 범위를 확인해 주세요.") Integer maxSets,
        @Schema(description = "동작 설명") @Size(max = 5000, message = "description 길이를 확인해 주세요.") String description,
        @Schema(description = "시범 영상") @Size(max = 500, message = "media_url 길이를 확인해 주세요.") String mediaUrl
) {
}
