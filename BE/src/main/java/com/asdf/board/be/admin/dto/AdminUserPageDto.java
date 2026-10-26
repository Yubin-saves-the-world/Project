package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record AdminUserPageDto(
        @Schema(description = "목록") List<AdminUserDto> items,
        Integer page,
        Integer pageSize,
        Integer total
) {
}
