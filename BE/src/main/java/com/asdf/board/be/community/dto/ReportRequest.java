package com.asdf.board.be.community.dto;

public record ReportRequest(String targetType, Long targetId, String reason, String detail) {}
