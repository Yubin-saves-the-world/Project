package com.asdf.board.be.notification.service;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.notification.dto.DeviceTokenRequest;
import com.asdf.board.be.notification.dto.NotificationSettingDto;
import com.asdf.board.be.notification.dto.NotificationSettingListDto;
import com.asdf.board.be.notification.dto.NotificationSettingPatch;
import com.asdf.board.be.notification.entity.DeviceToken;
import com.asdf.board.be.notification.entity.NotificationSetting;
import com.asdf.board.be.notification.repository.DeviceTokenRepository;
import com.asdf.board.be.notification.repository.NotificationSettingRepository;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private static final Pattern HHMM = Pattern.compile("^([01]\\d|2[0-3]):[0-5]\\d$");
    private static final DateTimeFormatter FORMAT = DateTimeFormatter.ofPattern("HH:mm");

    private final NotificationSettingRepository settingRepository;
    private final DeviceTokenRepository tokenRepository;
    private final UserRepository userRepository;
    private final AccessGuard accessGuard;

    @Transactional
    public NotificationSettingListDto list(Long userId) {
        accessGuard.requireOnboarded(userId);
        List<NotificationSettingDto> items = new ArrayList<>();
        ensure(userId).values().forEach(s -> items.add(dto(s)));
        return new NotificationSettingListDto(items);
    }

    @Transactional
    public NotificationSettingDto patch(Long userId, NotificationSetting.Type type, NotificationSettingPatch request) {
        accessGuard.requireOnboarded(userId);
        if (request.enabled() == null && request.time() == null) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        LocalTime time = null;
        if (request.time() != null) {
            if (type == NotificationSetting.Type.streak_risk || !HHMM.matcher(request.time()).matches()) {
                throw new ApiException(ErrorCode.VALIDATION_FAILED);
            }
            time = LocalTime.parse(request.time());
        }
        NotificationSetting setting = ensure(userId).get(type);
        if (request.enabled() != null) {
            setting.setEnabled(request.enabled());
        }
        if (time != null) {
            setting.setNotifyTime(time);
        }
        settingRepository.flush();
        return dto(setting);
    }

    @Transactional
    public void putDeviceToken(Long userId, DeviceTokenRequest request) {
        accessGuard.requireOnboarded(userId);
        String token = request.fcmToken().strip();
        if (token.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        String hash = hash(token);
        tokenRepository.deleteByHash(hash);
        DeviceToken existing = tokenRepository.findByUserIdAndPlatform(userId, request.platform()).orElse(null);
        if (existing == null) {
            tokenRepository.save(DeviceToken.builder().user(userRepository.getReferenceById(userId))
                    .fcmToken(token).tokenHash(hash).platform(request.platform()).build());
        } else {
            existing.setFcmToken(token);
            existing.setTokenHash(hash);
        }
        tokenRepository.flush();
    }

    private Map<NotificationSetting.Type, NotificationSetting> ensure(Long userId) {
        Map<NotificationSetting.Type, NotificationSetting> result = new EnumMap<>(NotificationSetting.Type.class);
        settingRepository.findByIdUserId(userId).forEach(s -> result.put(s.getId().getType(), s));
        for (NotificationSetting.Type type : NotificationSetting.Type.values()) {
            if (!result.containsKey(type)) {
                LocalTime time = switch (type) {
                    case workout -> LocalTime.of(19, 0);
                    case diet -> LocalTime.of(12, 0);
                    case streak_risk -> null;
                };
                result.put(type, settingRepository.save(NotificationSetting.builder()
                        .user(userRepository.getReferenceById(userId)).type(type).enabled(true).notifyTime(time).build()));
            }
        }
        settingRepository.flush();
        return result;
    }

    private static NotificationSettingDto dto(NotificationSetting s) {
        return new NotificationSettingDto(s.getId().getType().name(), s.getEnabled(),
                s.getNotifyTime() == null ? null : s.getNotifyTime().format(FORMAT));
    }

    private static String hash(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
