package com.asdf.board.be.notification.controller;

import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.notification.dto.DeviceTokenRequest;
import com.asdf.board.be.notification.dto.NotificationSettingDto;
import com.asdf.board.be.notification.dto.NotificationSettingListDto;
import com.asdf.board.be.notification.dto.NotificationSettingPatch;
import com.asdf.board.be.notification.entity.NotificationSetting;
import com.asdf.board.be.notification.service.NotificationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "notification", description = "알림")
@RestController
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @Operation(summary = "알림 설정 조회", description = "3종(workout, diet, streak_risk)을 모두 돌려줍니다.")
    @GetMapping("/api/notification-settings")
    public NotificationSettingListDto list(@AuthenticationPrincipal Jwt jwt) {
        return notificationService.list(CurrentUser.id(jwt));
    }

    @Operation(summary = "알림 설정 수정", description = "streak_risk는 시각을 바꿀 수 없습니다(서버 고정).")
    @PatchMapping("/api/notification-settings/{type}")
    public NotificationSettingDto patch(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("type") NotificationSetting.Type type,
            @Valid @RequestBody NotificationSettingPatch request) {
        return notificationService.patch(CurrentUser.id(jwt), type, request);
    }

    @Operation(summary = "푸시 기기 토큰 등록", description = "같은 사용자·플랫폼은 덮어씁니다.")
    @PutMapping("/api/users/me/device-token")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void putDeviceToken(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody DeviceTokenRequest request) {
        notificationService.putDeviceToken(CurrentUser.id(jwt), request);
    }
}
