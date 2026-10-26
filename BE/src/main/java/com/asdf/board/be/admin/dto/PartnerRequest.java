package com.asdf.board.be.admin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;

public record PartnerRequest(
        @Schema(description = "제휴사 이름") @NotBlank(message = "name을(를) 입력해 주세요.") @Size(max = 50, message = "name 길이를 확인해 주세요.") String name,
        @Schema(description = "계약 시작") @NotNull(message = "contract_start을(를) 입력해 주세요.") LocalDate contractStart,
        @Schema(description = "계약 종료") @NotNull(message = "contract_end을(를) 입력해 주세요.") LocalDate contractEnd
) {
}
