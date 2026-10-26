package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.OffsetDateTime;

public record PhotoDto(
        @Schema(description = "사진 ID") Long photoId,
        @Schema(description = "current 현재 체형 / goal 목표 체형") String type,
        @Schema(description = "촬영 방향") String side,
        @Schema(description = "접근 URL. 만료되는 서명 URL이므로 캐시하지 말고 만료 후 목록을 다시 조회") String url,
        @Schema(description = "url 만료 시각 (URL을 발급한 시각 + 1시간)") OffsetDateTime urlExpiresAt,
        @Schema(description = "업로드 시각") OffsetDateTime createdAt
) {
}
