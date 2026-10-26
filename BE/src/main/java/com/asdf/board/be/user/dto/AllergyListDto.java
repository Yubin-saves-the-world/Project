package com.asdf.board.be.user.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public record AllergyListDto(
        @Schema(description = "목록 (페이지 없음, 최대 50개)") List<AllergyDto> items
) {
}
