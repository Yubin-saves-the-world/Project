package com.asdf.board.be.auth.controller;

import com.asdf.board.be.auth.dto.EmailCodeConfirmRequest;
import com.asdf.board.be.auth.dto.EmailCodeRequest;
import com.asdf.board.be.auth.dto.EmailVerificationTokenResponse;
import com.asdf.board.be.auth.dto.LoginRequest;
import com.asdf.board.be.auth.dto.TokenResponse;
import com.asdf.board.be.auth.service.AuthService;
import com.asdf.board.be.auth.service.EmailVerificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "auth", description = "회원 · 인증")
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final EmailVerificationService emailVerificationService;

    @Operation(summary = "이메일 로그인", description = "onboarding_completed가 false면 앱이 신체정보(설문) 화면으로 이동합니다.")
    @SecurityRequirements
    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @Operation(summary = "이메일 인증번호 보내기", description = "입력한 이메일로 6자리 인증번호를 보냅니다. 5분 동안 유효하고, 같은 이메일은 60초에 한 번·1시간에 5번까지 요청할 수 있습니다. 이미 가입된 이메일이면 EMAIL_DUPLICATED.")
    @SecurityRequirements
    @PostMapping("/email-verifications")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void sendEmailCode(@Valid @RequestBody EmailCodeRequest request) {
        emailVerificationService.sendCode(request.email());
    }

    @Operation(summary = "이메일 인증번호 확인", description = "맞으면 verification_token을 돌려줍니다. 이 값을 회원가입 요청의 email_verification_token에 넣습니다. 5회 틀리면 인증번호를 다시 받아야 합니다.")
    @SecurityRequirements
    @PostMapping("/email-verifications/confirm")
    public EmailVerificationTokenResponse confirmEmailCode(@Valid @RequestBody EmailCodeConfirmRequest request) {
        return emailVerificationService.confirm(request.email(), request.code());
    }
}
