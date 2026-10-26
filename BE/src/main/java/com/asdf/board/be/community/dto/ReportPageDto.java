package com.asdf.board.be.community.dto;

import java.util.List;

public record ReportPageDto(List<ReportDto> items, Integer page, Integer pageSize, Integer total) {
}
