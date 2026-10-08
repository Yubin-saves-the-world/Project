package com.asdf.board.be.user.dto;

import com.asdf.board.be.user.entity.User;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

public record UserCreatedResponse(Long userId, String email, String nickname, OffsetDateTime createdAt) {

    private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");

    public static UserCreatedResponse from(User user) {
        return new UserCreatedResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getCreatedAt().truncatedTo(ChronoUnit.SECONDS).atZone(SEOUL).toOffsetDateTime());
    }
}
