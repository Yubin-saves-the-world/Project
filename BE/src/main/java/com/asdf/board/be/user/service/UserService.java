package com.asdf.board.be.user.service;

import com.asdf.board.be.auth.service.EmailVerificationService;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.body.service.AnalysisService;
import com.asdf.board.be.body.service.GoalBodyService;
import com.asdf.board.be.user.dto.SignupRequest;
import com.asdf.board.be.user.dto.UserPatch;
import com.asdf.board.be.user.dto.UserCreatedResponse;
import com.asdf.board.be.user.dto.UserMeResponse;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.repository.UserConsentRepository;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.Map;
import java.util.List;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final UserConsentRepository userConsentRepository;
    private final UserProfileRepository userProfileRepository;
    private final PasswordEncoder passwordEncoder;
    private final EntityManager entityManager;
    private final EmailVerificationService emailVerificationService;
    private final AnalysisService analysisService;
    private final GoalBodyService goalBodyService;
    private final AccessGuard accessGuard;

    @Value("${vitality.policy-version}")
    private String currentPolicyVersion;

    @Transactional
    public UserCreatedResponse signup(SignupRequest request) {
        if (!request.allConsentsAgreed()) {
            throw new ApiException(ErrorCode.TERMS_REQUIRED);
        }
        emailVerificationService.assertVerified(request.email(), request.emailVerificationToken());
        if (userRepository.existsByEmail(request.email())) {
            throw new ApiException(ErrorCode.EMAIL_DUPLICATED);
        }
        if (userRepository.existsByNickname(request.nickname())) {
            throw new ApiException(ErrorCode.NICKNAME_DUPLICATED);
        }

        User user = userRepository.save(User.builder()
                .email(request.email())
                .passwordHash(passwordEncoder.encode(request.password()))
                .nickname(request.nickname())
                .build());
        entityManager.flush();
        entityManager.refresh(user);

        String policyVersion = request.policyVersion() != null ? request.policyVersion() : currentPolicyVersion;
        List<UserConsent> consents = Arrays.stream(UserConsent.ConsentType.values())
                .map(type -> UserConsent.builder()
                        .user(user)
                        .consentType(type)
                        .agreed(true)
                        .policyVersion(policyVersion)
                        .source(UserConsent.Source.signup)
                        .build())
                .toList();
        userConsentRepository.saveAll(consents);
        emailVerificationService.consume(request.email());

        return UserCreatedResponse.from(user);
    }

    @Transactional(readOnly = true)
    public UserMeResponse getMe(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(ApiException.of(ErrorCode.UNAUTHORIZED));

        Map<UserConsent.ConsentType, Boolean> current = new EnumMap<>(UserConsent.ConsentType.class);
        userConsentRepository.findByUserIdOrderByIdAsc(userId)
                .forEach(consent -> current.put(consent.getConsentType(), consent.getAgreed()));

        boolean consentCompleted = Arrays.stream(UserConsent.ConsentType.values())
                .allMatch(type -> Boolean.TRUE.equals(current.get(type)));
        return UserMeResponse.of(
                user,
                userProfileRepository.existsByUserId(userId),
                consentCompleted,
                Boolean.TRUE.equals(current.get(UserConsent.ConsentType.body_photo)),
                Boolean.TRUE.equals(current.get(UserConsent.ConsentType.ai_processing)));
    }

    @Transactional
    public UserMeResponse patch(Long userId, UserPatch request) {
        if (request.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        if (Boolean.FALSE.equals(request.termsAgreed()) || Boolean.FALSE.equals(request.privacyAgreed())) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        User user = userRepository.findById(userId).orElseThrow(ApiException.of(ErrorCode.UNAUTHORIZED));
        if (request.nickname() != null && !request.nickname().equals(user.getNickname())) {
            if (userRepository.existsByNickname(request.nickname())) {
                throw new ApiException(ErrorCode.NICKNAME_DUPLICATED);
            }
            user.setNickname(request.nickname());
        }
        record Change(UserConsent.ConsentType type, Boolean value) {
        }
        List<Change> changes = List.of(
                new Change(UserConsent.ConsentType.terms, request.termsAgreed()),
                new Change(UserConsent.ConsentType.privacy, request.privacyAgreed()),
                new Change(UserConsent.ConsentType.body_photo, request.bodyPhotoAgreed()),
                new Change(UserConsent.ConsentType.ai_processing, request.aiProcessingAgreed()));
        for (Change change : changes) {
            if (change.value() != null && change.value() != accessGuard.agreed(userId, change.type())) {
                userConsentRepository.save(UserConsent.builder()
                        .user(user)
                        .consentType(change.type())
                        .agreed(change.value())
                        .policyVersion(currentPolicyVersion)
                        .source(UserConsent.Source.settings)
                        .build());
                if (change.type() == UserConsent.ConsentType.ai_processing && !change.value()) {
                    analysisService.cancelPending(userId, "AI 처리 동의가 철회되어 분석을 중단했어요.");
                    goalBodyService.cancelPending(userId, "AI 처리 동의가 철회되어 분석을 중단했어요.");
                }
            }
        }
        userRepository.flush();
        return getMe(userId);
    }
}
