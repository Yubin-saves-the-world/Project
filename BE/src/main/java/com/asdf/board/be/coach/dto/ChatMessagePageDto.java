package com.asdf.board.be.coach.dto;

import java.util.List;

public record ChatMessagePageDto(
        List<ChatMessageDto> items,
        Integer page,
        Integer pageSize,
        Integer total
) {
}
