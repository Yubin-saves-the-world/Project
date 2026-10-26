package com.asdf.board.be.community.dto;

import java.util.List;

public record PostPageDto(List<PostSummaryDto> items, Integer page, Integer pageSize, Integer total) {
}
