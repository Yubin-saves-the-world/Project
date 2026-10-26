package com.asdf.board.be.user.controller;

import com.asdf.board.be.user.dto.SignupRequest;
import com.asdf.board.be.user.dto.UserCreatedResponse;
import com.asdf.board.be.user.dto.UserMeResponse;
import com.asdf.board.be.user.dto.UserPatch;
import com.asdf.board.be.user.service.UserService;
import com.asdf.board.be.user.service.WithdrawalService;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
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
    private final WithdrawalService withdrawalService;

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

    @Operation(summary = "내 정보 수정", description = "닉네임 변경과 동의 변경. terms·privacy는 true만 허용(철회는 회원 탈퇴), body_photo·ai_processing은 철회 가능. 1개 이상 필수.")
    @PatchMapping("/me")
    public UserMeResponse patch(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody UserPatch request) {
        return userService.patch(Long.valueOf(jwt.getSubject()), request);
    }

    @Operation(summary = "회원 탈퇴", description = "즉시 로그인이 불가능해지고 개인정보·사진·분석·운동 기록이 삭제됩니다. 같은 이메일로 다시 가입할 수 있습니다.")
    @DeleteMapping("/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void withdraw(@AuthenticationPrincipal Jwt jwt) {
        withdrawalService.withdraw(Long.valueOf(jwt.getSubject()));
    }
}
