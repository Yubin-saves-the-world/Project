package com.asdf.board.be.community.dto;

import java.util.List;

public record BlockPageDto(List<BlockedUserDto> items, Integer page, Integer pageSize, Integer total) {
}
