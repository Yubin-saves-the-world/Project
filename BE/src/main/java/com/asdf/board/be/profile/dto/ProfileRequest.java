package com.asdf.board.be.profile.dto;

import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.user.entity.UserProfile;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record ProfileRequest(
        @Schema(description = "키(cm). 소수 첫째 자리까지", example = "174.0")
        @NotNull(message = "키를 입력해 주세요.")
        @DecimalMin(value = "100.0", message = "키는 100~250cm 사이여야 합니다.")
        @DecimalMax(value = "250.0", message = "키는 100~250cm 사이여야 합니다.")
        @Digits(integer = 3, fraction = 1, message = "키는 소수 첫째 자리까지 입력할 수 있습니다.")
        BigDecimal heightCm,

        @Schema(description = "몸무게(kg). 소수 첫째 자리까지", example = "68.0")
        @NotNull(message = "몸무게를 입력해 주세요.")
        @DecimalMin(value = "30.0", message = "몸무게는 30~250kg 사이여야 합니다.")
        @DecimalMax(value = "250.0", message = "몸무게는 30~250kg 사이여야 합니다.")
        @Digits(integer = 3, fraction = 1, message = "몸무게는 소수 첫째 자리까지 입력할 수 있습니다.")
        BigDecimal weightKg,

        @Schema(description = "나이", example = "18")
        @NotNull(message = "나이를 입력해 주세요.")
        @Min(value = 10, message = "나이는 10~100세 사이여야 합니다.")
        @Max(value = 100, message = "나이는 10~100세 사이여야 합니다.")
        Integer age,

        @Schema(description = "성별. 생략하면 none", example = "male")
        UserProfile.Gender gender,

        @Schema(description = "운동 목적: muscle 근육 키우기 / diet 체중 줄이기 / posture 자세 교정", example = "muscle")
        @NotNull(message = "운동 목적을 선택해 주세요.")
        UserProfile.GoalType goalType,

        @Schema(description = "주 운동 가능 횟수(1~7). 앱의 0~1회=1, 2~3회=3, 4~5회=5, 6~7회=7", example = "5")
        @NotNull(message = "주 운동 횟수를 선택해 주세요.")
        @Min(value = 1, message = "주 운동 횟수는 1~7회 사이여야 합니다.")
        @Max(value = 7, message = "주 운동 횟수는 1~7회 사이여야 합니다.")
        Integer weeklyFrequency,

        @Schema(description = "운동 경력: under3m 3개월 미만 / under1y 1년 미만 / over1y 1년 이상", example = "over1y")
        @NotNull(message = "운동 경력을 선택해 주세요.")
        ExperienceLevel experienceLevel
) {
}
