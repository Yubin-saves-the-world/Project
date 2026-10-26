package com.asdf.board.be.profile.dto;

import java.util.List;

public record ProfilePageDto(
        List<ProfileResponse> items,
        Integer page,
        Integer pageSize,
        Integer total
) {
}
