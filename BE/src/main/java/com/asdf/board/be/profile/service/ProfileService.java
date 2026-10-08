package com.asdf.board.be.profile.service;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.profile.dto.ProfilePatchRequest;
import com.asdf.board.be.profile.dto.ProfileRequest;
import com.asdf.board.be.profile.dto.ProfileResponse;
import com.asdf.board.be.profile.dto.ProfileUpdatedResponse;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.entity.UserProfile;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ProfileService {

    private final UserRepository userRepository;
    private final UserProfileRepository profileRepository;
    private final EntityManager entityManager;

    @Transactional
    public ProfileResponse create(Long userId, ProfileRequest request) {
        User user = lockUser(userId);
        if (profileRepository.existsByUserId(userId)) {
            throw new ApiException(ErrorCode.PROFILE_ALREADY_EXISTS);
        }
        UserProfile saved = profileRepository.saveAndFlush(UserProfile.builder()
                .user(user)
                .heightCm(oneDecimal(request.heightCm()))
                .weightKg(oneDecimal(request.weightKg()))
                .age(request.age())
                .gender(request.gender())
                .goalType(request.goalType())
                .weeklyFrequency(request.weeklyFrequency())
                .experienceLevel(request.experienceLevel())
                .build());
        entityManager.refresh(saved);
        return ProfileResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public ProfileResponse getLatest(Long userId) {
        return ProfileResponse.from(latest(userId));
    }

    @Transactional
    public ProfileUpdatedResponse update(Long userId, ProfilePatchRequest request) {
        if (request.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        User user = lockUser(userId);
        UserProfile previous = latest(userId);

        UserProfile saved = profileRepository.saveAndFlush(UserProfile.builder()
                .user(user)
                .heightCm(request.heightCm() != null ? oneDecimal(request.heightCm()) : previous.getHeightCm())
                .weightKg(request.weightKg() != null ? oneDecimal(request.weightKg()) : previous.getWeightKg())
                .age(request.age() != null ? request.age() : previous.getAge())
                .gender(request.gender() != null ? request.gender() : previous.getGender())
                .goalType(request.goalType() != null ? request.goalType() : previous.getGoalType())
                .weeklyFrequency(request.weeklyFrequency() != null ? request.weeklyFrequency() : previous.getWeeklyFrequency())
                .experienceLevel(request.experienceLevel() != null ? request.experienceLevel() : previous.getExperienceLevel())
                .build());
        entityManager.refresh(saved);

        boolean routineRefreshRecommended = saved.getGoalType() != previous.getGoalType()
                || !saved.getWeeklyFrequency().equals(previous.getWeeklyFrequency())
                || saved.getExperienceLevel() != previous.getExperienceLevel();
        return ProfileUpdatedResponse.of(ProfileResponse.from(saved), routineRefreshRecommended);
    }

    private User lockUser(Long userId) {
        return userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
    }

    private UserProfile latest(Long userId) {
        return profileRepository.findFirstByUserIdOrderByIdDesc(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.PROFILE_NOT_FOUND));
    }

    private static BigDecimal oneDecimal(BigDecimal value) {
        return value.setScale(1, RoundingMode.HALF_UP);
    }
}
