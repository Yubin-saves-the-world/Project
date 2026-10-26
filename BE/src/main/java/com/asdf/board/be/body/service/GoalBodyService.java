package com.asdf.board.be.body.service;

import com.asdf.board.be.body.ai.BodyAiClient;
import com.asdf.board.be.body.dto.GoalBodyDto;
import com.asdf.board.be.body.dto.GoalPatch;
import com.asdf.board.be.body.dto.GoalRequest;
import com.asdf.board.be.body.entity.GoalBody;
import com.asdf.board.be.body.entity.Photo;
import com.asdf.board.be.body.repository.GoalBodyRepository;
import com.asdf.board.be.body.repository.PhotoRepository;
import com.asdf.board.be.global.async.AsyncRunner;
import com.asdf.board.be.global.config.VitalityProperties;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.storage.PhotoStorage;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import java.time.Clock;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Slf4j
@Service
@RequiredArgsConstructor
public class GoalBodyService {

    private static final String TIMEOUT_MESSAGE = "목표 체형 분석이 오래 걸려 중단했어요. 다시 시도해 주세요.";

    private final GoalBodyRepository goalBodyRepository;
    private final PhotoRepository photoRepository;
    private final UserRepository userRepository;
    private final PhotoStorage storage;
    private final AccessGuard accessGuard;
    private final BodyAiClient aiClient;
    private final AsyncRunner asyncRunner;
    private final VitalityProperties properties;
    private final PlatformTransactionManager transactionManager;
    private final Clock clock;

    @Transactional
    public GoalBodyDto create(Long userId, GoalRequest request) {
        accessGuard.requireOnboarded(userId);
        boolean hasDescription = request.description() != null && !request.description().isBlank();
        if (request.photoId() == null && !hasDescription) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        Photo photo = request.photoId() == null ? null : goalPhoto(userId, request.photoId());
        if (goalBodyRepository.existsByUserId(userId)) {
            throw new ApiException(ErrorCode.GOAL_ALREADY_EXISTS);
        }
        GoalBody goal = goalBodyRepository.save(GoalBody.builder()
                .user(userRepository.getReferenceById(userId))
                .status(photo == null ? GoalBody.Status.done : GoalBody.Status.pending)
                .description(hasDescription ? request.description().trim() : null)
                .sourcePhoto(photo)
                .build());
        goalBodyRepository.flush();
        if (photo != null) {
            Long goalId = goal.getId();
            asyncRunner.run(() -> process(goalId));
        }
        return toDto(goal);
    }

    @Transactional(readOnly = true)
    public GoalBodyDto get(Long userId) {
        accessGuard.requireOnboarded(userId);
        return toDto(goalBodyRepository.findFirstByUserIdOrderByIdDesc(userId)
                .orElseThrow(ApiException.of(ErrorCode.GOAL_NOT_FOUND)));
    }

    @Transactional
    public GoalBodyDto update(Long userId, Long goalId, GoalPatch request) {
        accessGuard.requireOnboarded(userId);
        boolean hasDescription = request.description() != null;
        if (request.photoId() == null && !hasDescription) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        GoalBody goal = goalBodyRepository.findByIdAndUserId(goalId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        Photo photo = request.photoId() == null ? null : goalPhoto(userId, request.photoId());
        if (hasDescription) {
            goal.setDescription(request.description().isBlank() ? null : request.description().trim());
        }
        if (photo != null) {
            discardSourcePhoto(goal);
            goal.setSourcePhoto(photo);
            goal.setStatus(GoalBody.Status.pending);
            goal.setSummary(null);
            goal.setErrorMessage(null);
            goalBodyRepository.flush();
            asyncRunner.run(() -> process(goalId));
        } else if (goal.getStatus() != GoalBody.Status.pending) {
            goal.setStatus(GoalBody.Status.done);
            goal.setErrorMessage(null);
        }
        goalBodyRepository.flush();
        return toDto(goal);
    }

    @Transactional
    public void delete(Long userId, Long goalId) {
        accessGuard.requireOnboarded(userId);
        GoalBody goal = goalBodyRepository.findByIdAndUserId(goalId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        discardSourcePhoto(goal);
        goalBodyRepository.delete(goal);
        goalBodyRepository.flush();
    }

    public void process(Long goalId) {
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        record Job(Long photoId, String description, byte[] bytes) {
        }
        Job job = tx.execute(status -> goalBodyRepository.findById(goalId)
                .filter(g -> g.getStatus() == GoalBody.Status.pending && g.getSourcePhoto() != null)
                .map(g -> new Job(g.getSourcePhoto().getId(), g.getDescription(),
                        storage.get(g.getSourcePhoto().getStorageKey())))
                .orElse(null));
        if (job == null) {
            return;
        }
        BodyAiClient.GoalFeatures result;
        try {
            result = aiClient.extractGoalFeatures(job.bytes(), job.description());
        } catch (RuntimeException e) {
            log.error("목표 체형 특징 추출 실패 goal={}", goalId, e);
            result = new BodyAiClient.GoalFeatures(false, null, "목표 체형 분석에 실패했어요. 다시 시도해 주세요.");
        }
        BodyAiClient.GoalFeatures finalResult = result;
        tx.executeWithoutResult(status -> goalBodyRepository.findById(goalId)
                .filter(g -> g.getStatus() == GoalBody.Status.pending
                        && g.getSourcePhoto() != null && g.getSourcePhoto().getId().equals(job.photoId()))
                .ifPresent(g -> {
                    if (finalResult.ok()) {
                        g.setStatus(GoalBody.Status.done);
                        g.setSummary(finalResult.summary());
                        g.setErrorMessage(null);
                        discardSourcePhoto(g);
                    } else {
                        fail(g, finalResult.errorMessage());
                    }
                    goalBodyRepository.flush();
                }));
    }

    @Transactional
    public int failTimedOut() {
        LocalDateTime limit = LocalDateTime.now(clock).minus(properties.analysis().timeout());
        var stuck = goalBodyRepository.findByStatusAndCreatedAtBefore(GoalBody.Status.pending, limit);
        stuck.forEach(g -> fail(g, TIMEOUT_MESSAGE));
        goalBodyRepository.flush();
        return stuck.size();
    }

    @Transactional
    public void cancelPending(Long userId, String message) {
        goalBodyRepository.findFirstByUserIdOrderByIdDesc(userId)
                .filter(g -> g.getStatus() == GoalBody.Status.pending)
                .ifPresent(g -> fail(g, message));
    }

    private void fail(GoalBody goal, String message) {
        goal.setStatus(GoalBody.Status.failed);
        goal.setErrorMessage(message);
        discardSourcePhoto(goal);
    }

    private Photo goalPhoto(Long userId, Long photoId) {
        accessGuard.requireConsent(userId, UserConsent.ConsentType.body_photo, UserConsent.ConsentType.ai_processing);
        Photo photo = photoRepository.findByIdAndUserId(photoId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (photo.getType() != Photo.Type.goal) {
            throw new ApiException(ErrorCode.PHOTO_TYPE_MISMATCH);
        }
        return photo;
    }

    private void discardSourcePhoto(GoalBody goal) {
        Photo photo = goal.getSourcePhoto();
        if (photo != null) {
            goal.setSourcePhoto(null);
            storage.delete(photo.getStorageKey());
            photoRepository.delete(photo);
        }
    }

    private GoalBodyDto toDto(GoalBody goal) {
        boolean pending = goal.getStatus() == GoalBody.Status.pending;
        return new GoalBodyDto(
                goal.getId(),
                goal.getStatus().name(),
                goal.getSummary(),
                goal.getErrorMessage(),
                pending ? properties.analysis().pollAfterMs() : null,
                goal.getDescription(),
                Times.offset(goal.getCreatedAt()));
    }
}
