package com.asdf.board.be.profile.dto;

import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.user.entity.UserProfile;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ProfileResponse(
        Long profileId,
        BigDecimal heightCm,
        BigDecimal weightKg,
        Integer age,
        UserProfile.Gender gender,
        UserProfile.GoalType goalType,
        Integer weeklyFrequency,
        ExperienceLevel experienceLevel,
        OffsetDateTime measuredAt
) {


    public static ProfileResponse from(UserProfile p) {
        return new ProfileResponse(
                p.getId(),
                p.getHeightCm(),
                p.getWeightKg(),
                p.getAge(),
                p.getGender(),
                p.getGoalType(),
                p.getWeeklyFrequency(),
                p.getExperienceLevel(),
                Times.offset(p.getMeasuredAt()));
    }
}
