package com.asdf.board.be.user.dto;

import com.asdf.board.be.user.entity.User;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

public record UserMeResponse(
        Long userId,
        String email,
        String nickname,
        User.Role role,
        @Schema(description = "신체정보 입력 완료 여부. false면 앱이 신체정보(설문) 화면으로 이동")
        boolean onboardingCompleted,
        @Schema(description = "필수 동의 4종이 모두 true인지. false면 앱이 동의 화면으로 이동")
        boolean consentCompleted,
        boolean bodyPhotoAgreed,
        boolean aiProcessingAgreed,
        OffsetDateTime createdAt
) {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    public static UserMeResponse of(
            User user, boolean onboardingCompleted, boolean consentCompleted,
            boolean bodyPhotoAgreed, boolean aiProcessingAgreed) {
        return new UserMeResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getRole(),
                onboardingCompleted,
                consentCompleted,
                bodyPhotoAgreed,
                aiProcessingAgreed,
                user.getCreatedAt().truncatedTo(ChronoUnit.SECONDS).atZone(SEOUL).toOffsetDateTime());
    }
}
