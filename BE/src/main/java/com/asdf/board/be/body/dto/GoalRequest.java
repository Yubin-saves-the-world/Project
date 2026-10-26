package com.asdf.board.be.body.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;

public record GoalRequest(
        @Schema(description = "목표 사진 ID (type=goal). 서버가 특징을 추출한 뒤 사진을 삭제하므로 한 번 쓰면 다시 쓸 수 없음") Long photoId,
        @Schema(description = "목표 체형 설명") @Size(min = 1, max = 200, message = "description 길이를 확인해 주세요.") String description
) {
}
