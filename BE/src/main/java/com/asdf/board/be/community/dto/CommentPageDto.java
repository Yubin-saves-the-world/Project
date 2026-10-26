package com.asdf.board.be.community.dto;

import java.util.List;

public record CommentPageDto(List<CommentDto> items, Integer page, Integer pageSize, Integer total) {
}
