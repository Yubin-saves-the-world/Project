package com.asdf.board.be.profile.dto;

import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.user.entity.UserProfile;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.math.BigDecimal;

@Schema(description = "1개 이상 필수. 보내지 않은 필드는 직전 값을 이어받습니다.")
public record ProfilePatchRequest(
        @Schema(description = "키(cm)", example = "175.0")
        @DecimalMin(value = "100.0", message = "키는 100~250cm 사이여야 합니다.")
        @DecimalMax(value = "250.0", message = "키는 100~250cm 사이여야 합니다.")
        @Digits(integer = 3, fraction = 1, message = "키는 소수 첫째 자리까지 입력할 수 있습니다.")
        BigDecimal heightCm,

        @Schema(description = "몸무게(kg)", example = "70.5")
        @DecimalMin(value = "30.0", message = "몸무게는 30~250kg 사이여야 합니다.")
        @DecimalMax(value = "250.0", message = "몸무게는 30~250kg 사이여야 합니다.")
        @Digits(integer = 3, fraction = 1, message = "몸무게는 소수 첫째 자리까지 입력할 수 있습니다.")
        BigDecimal weightKg,

        @Schema(description = "나이", example = "18")
        @Min(value = 10, message = "나이는 10~100세 사이여야 합니다.")
        @Max(value = 100, message = "나이는 10~100세 사이여야 합니다.")
        Integer age,

        @Schema(description = "성별", example = "male")
        UserProfile.Gender gender,

        @Schema(description = "운동 목적", example = "diet")
        UserProfile.GoalType goalType,

        @Schema(description = "주 운동 가능 횟수(1~7)", example = "3")
        @Min(value = 1, message = "주 운동 횟수는 1~7회 사이여야 합니다.")
        @Max(value = 7, message = "주 운동 횟수는 1~7회 사이여야 합니다.")
        Integer weeklyFrequency,

        @Schema(description = "운동 경력", example = "over1y")
        ExperienceLevel experienceLevel
) {

    public boolean isEmpty() {
        return heightCm == null && weightKg == null && age == null && gender == null
                && goalType == null && weeklyFrequency == null && experienceLevel == null;
    }
}
