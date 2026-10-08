package com.asdf.board.be.profile.dto;

import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.user.entity.UserProfile;
import io.swagger.v3.oas.annotations.media.Schema;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ProfileUpdatedResponse(
        Long profileId,
        BigDecimal heightCm,
        BigDecimal weightKg,
        Integer age,
        UserProfile.Gender gender,
        UserProfile.GoalType goalType,
        Integer weeklyFrequency,
        ExperienceLevel experienceLevel,
        OffsetDateTime measuredAt,
        @Schema(description = "운동 목적·횟수·경력이 바뀌었으면 true. 앱이 루틴 다시 만들기를 안내")
        boolean routineRefreshRecommended
) {

    public static ProfileUpdatedResponse of(ProfileResponse p, boolean routineRefreshRecommended) {
        return new ProfileUpdatedResponse(
                p.profileId(), p.heightCm(), p.weightKg(), p.age(), p.gender(), p.goalType(),
                p.weeklyFrequency(), p.experienceLevel(), p.measuredAt(), routineRefreshRecommended);
    }
}
