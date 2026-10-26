package com.asdf.board.be.user.service;

import com.asdf.board.be.global.web.Texts;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.user.dto.AllergyDto;
import com.asdf.board.be.user.dto.AllergyListDto;
import com.asdf.board.be.user.dto.AllergyRequest;
import com.asdf.board.be.user.entity.UserAllergy;
import com.asdf.board.be.user.repository.UserAllergyRepository;
import com.asdf.board.be.user.repository.UserRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AllergyService {

    static final int MAX_ITEMS = 50;

    private final UserAllergyRepository allergies;
    private final UserRepository users;
    private final AccessGuard accessGuard;

    @Transactional(readOnly = true)
    public AllergyListDto list(Long userId) {
        accessGuard.requireOnboarded(userId);
        return new AllergyListDto(allergies.findByUserIdOrderByIdAsc(userId).stream().map(AllergyService::toDto).toList());
    }

    @Transactional
    public AllergyDto create(Long userId, AllergyRequest request) {
        accessGuard.requireOnboarded(userId);
        users.findByIdForUpdate(userId).orElseThrow(ApiException.of(ErrorCode.UNAUTHORIZED));
        String item = request.item().strip().replaceAll("\\s+", " ");
        if (item.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        List<UserAllergy> existing = allergies.findByUserIdOrderByIdAsc(userId);
        String key = Texts.compact(item);
        if (existing.stream().anyMatch(a -> Texts.compact(a.getItem()).equals(key))) {
            throw new ApiException(ErrorCode.ALLERGY_DUPLICATED);
        }
        if (existing.size() >= MAX_ITEMS) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        UserAllergy saved = allergies.saveAndFlush(UserAllergy.builder()
                .user(users.getReferenceById(userId)).item(item).build());
        return toDto(saved);
    }

    @Transactional
    public void delete(Long userId, Long allergyId) {
        accessGuard.requireOnboarded(userId);
        UserAllergy allergy = allergies.findByIdAndUserId(allergyId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        allergies.delete(allergy);
    }

    private static AllergyDto toDto(UserAllergy a) {
        return new AllergyDto(a.getId(), a.getItem(), Times.offset(a.getCreatedAt()));
    }
}
