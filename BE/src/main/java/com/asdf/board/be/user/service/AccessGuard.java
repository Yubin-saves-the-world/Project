package com.asdf.board.be.user.service;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.repository.UserConsentRepository;
import com.asdf.board.be.user.repository.UserProfileRepository;
import java.util.EnumMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class AccessGuard {

    private final UserProfileRepository profiles;
    private final UserConsentRepository consents;

    public void requireOnboarded(Long userId) {
        if (!profiles.existsByUserId(userId)) {
            throw new ApiException(ErrorCode.ONBOARDING_REQUIRED);
        }
    }

    public boolean agreed(Long userId, UserConsent.ConsentType type) {
        return current(userId).getOrDefault(type, false);
    }

    public void requireConsent(Long userId, UserConsent.ConsentType... types) {
        Map<UserConsent.ConsentType, Boolean> current = current(userId);
        for (UserConsent.ConsentType type : types) {
            if (!current.getOrDefault(type, false)) {
                throw new ApiException(ErrorCode.CONSENT_REQUIRED);
            }
        }
    }

    private Map<UserConsent.ConsentType, Boolean> current(Long userId) {
        Map<UserConsent.ConsentType, Boolean> result = new EnumMap<>(UserConsent.ConsentType.class);
        consents.findByUserIdOrderByIdAsc(userId).forEach(c -> result.put(c.getConsentType(), c.getAgreed()));
        return result;
    }
}
