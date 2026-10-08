package com.asdf.board.be.user.controller;

import com.asdf.board.be.user.dto.SignupRequest;
import com.asdf.board.be.user.dto.UserCreatedResponse;
import com.asdf.board.be.user.dto.UserMeResponse;
import com.asdf.board.be.user.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "auth", description = "회원 · 인증")
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @Operation(summary = "회원가입", description = "가입만 하고 토큰은 발급하지 않습니다. 이어서 로그인 API를 호출하세요. 동의 4개가 모두 true여야 합니다.")
    @SecurityRequirements
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserCreatedResponse signup(@Valid @RequestBody SignupRequest request) {
        return userService.signup(request);
    }

    @Operation(summary = "내 정보 조회", description = "앱은 로그인 직후와 실행 시 이 응답으로 첫 화면을 정합니다. consent_completed=false면 동의 화면, onboarding_completed=false면 신체정보 입력, 그 외 홈.")
    @GetMapping("/me")
    public UserMeResponse me(@AuthenticationPrincipal Jwt jwt) {
        return userService.getMe(Long.valueOf(jwt.getSubject()));
    }
}
