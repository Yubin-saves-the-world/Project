package com.asdf.board.be.profile.controller;

import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.profile.dto.ProfilePageDto;
import com.asdf.board.be.profile.dto.ProfilePatchRequest;
import com.asdf.board.be.profile.dto.ProfileRequest;
import com.asdf.board.be.profile.dto.ProfileResponse;
import com.asdf.board.be.profile.dto.ProfileUpdatedResponse;
import com.asdf.board.be.profile.service.ProfileService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "profile", description = "신체정보 · 설문")
@Validated
@RestController
@RequestMapping("/api/users/me/profile")
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileService profileService;

    @Operation(summary = "신체정보 등록", description = "가입 직후 설문 화면에서 최초 1회 호출합니다. 성공하면 로그인 응답의 onboarding_completed가 true가 됩니다. 이미 있으면 PROFILE_ALREADY_EXISTS.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProfileResponse create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ProfileRequest request) {
        return profileService.create(Long.valueOf(jwt.getSubject()), request);
    }

    @Operation(summary = "신체정보 조회", description = "가장 최근에 기록된 값을 반환합니다.")
    @GetMapping
    public ProfileResponse get(@AuthenticationPrincipal Jwt jwt) {
        return profileService.getLatest(Long.valueOf(jwt.getSubject()));
    }

    @Operation(summary = "신체정보 이력", description = "저장할 때마다 쌓인 이력을 최신순으로 돌려줍니다. 등록 전이면 items=[]입니다.")
    @GetMapping("/history")
    public ProfilePageDto history(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return profileService.history(CurrentUser.id(jwt), page, pageSize);
    }

    @Operation(summary = "신체정보 수정", description = "값을 덮어쓰지 않고 새 이력 행으로 저장합니다. 보내지 않은 필드는 직전 값을 이어받습니다.")
    @PatchMapping
    public ProfileUpdatedResponse update(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ProfilePatchRequest request) {
        return profileService.update(Long.valueOf(jwt.getSubject()), request);
    }
}
