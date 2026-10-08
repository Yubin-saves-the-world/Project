package com.asdf.board.be.profile.dto;

import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.user.entity.UserProfile;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

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

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

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
                p.getMeasuredAt().truncatedTo(ChronoUnit.SECONDS).atZone(SEOUL).toOffsetDateTime());
    }
}
