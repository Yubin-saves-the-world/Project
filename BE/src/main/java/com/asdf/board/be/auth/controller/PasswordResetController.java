package com.asdf.board.be.auth.controller;

import com.asdf.board.be.auth.dto.PasswordResetConfirmRequest;
import com.asdf.board.be.auth.dto.PasswordResetRequest;
import com.asdf.board.be.auth.dto.PasswordResetTokenResponse;
import com.asdf.board.be.auth.dto.PasswordResetVerifyRequest;
import com.asdf.board.be.auth.service.PasswordResetService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "auth", description = "회원 · 인증")
@RestController
@RequestMapping("/api/auth/password")
@RequiredArgsConstructor
public class PasswordResetController {

    private final PasswordResetService passwordResetService;

    @Operation(summary = "비밀번호 재설정 인증번호 요청", description = "가입 여부와 관계없이 항상 204를 돌려줍니다(계정 존재 여부 노출 방지). 가입된 이메일이면 6자리 인증번호를 메일로 보냅니다. 5분 동안 유효하고, 같은 이메일은 60초에 한 번·1시간에 5번까지 보냅니다. 제한에 걸리면 새 메일 없이 204만 돌려줍니다.")
    @SecurityRequirements
    @PostMapping("/reset-request")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void requestReset(@Valid @RequestBody PasswordResetRequest request) {
        passwordResetService.requestReset(request.email());
    }

    @Operation(summary = "비밀번호 재설정 인증번호 확인", description = "맞으면 reset_token을 돌려줍니다. 이 값을 비밀번호 재설정 요청의 token에 넣습니다. 5회 틀리면 인증번호를 다시 받아야 합니다.")
    @SecurityRequirements
    @PostMapping("/reset-verification")
    public PasswordResetTokenResponse verify(@Valid @RequestBody PasswordResetVerifyRequest request) {
        return passwordResetService.verifyCode(request.email(), request.code());
    }

    @Operation(summary = "비밀번호 재설정", description = "reset_token으로 새 비밀번호를 저장합니다. 토큰은 30분 동안 한 번만 쓸 수 있습니다. 이미 발급된 로그인 토큰은 만료까지 유지됩니다.")
    @SecurityRequirements
    @PatchMapping("/reset")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reset(@Valid @RequestBody PasswordResetConfirmRequest request) {
        passwordResetService.reset(request.token(), request.newPassword());
    }
}
