package com.asdf.board.be.user.dto;

import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.user.entity.User;
import java.time.OffsetDateTime;

public record UserCreatedResponse(Long userId, String email, String nickname, OffsetDateTime createdAt) {


    public static UserCreatedResponse from(User user) {
        return new UserCreatedResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                Times.offset(user.getCreatedAt()));
    }
}
