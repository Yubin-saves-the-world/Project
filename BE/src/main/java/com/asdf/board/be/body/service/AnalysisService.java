package com.asdf.board.be.body.service;

import com.asdf.board.be.body.ai.BodyAiClient;
import com.asdf.board.be.body.dto.AnalysisAcceptedDto;
import com.asdf.board.be.body.dto.AnalysisDto;
import com.asdf.board.be.body.dto.AnalysisPageDto;
import com.asdf.board.be.body.dto.AnalysisRequest;
import com.asdf.board.be.body.dto.AnalysisSummaryDto;
import com.asdf.board.be.body.dto.AnalysisUsageDto;
import com.asdf.board.be.body.dto.BodyPartDto;
import com.asdf.board.be.body.dto.GoalComparisonDto;
import com.asdf.board.be.body.dto.JudgementDto;
import com.asdf.board.be.body.dto.MeasureUnavailableDto;
import com.asdf.board.be.body.dto.MeasuresDto;
import com.asdf.board.be.body.dto.TextAnalysisRequest;
import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.body.entity.GoalBody;
import com.asdf.board.be.body.entity.Photo;
import com.asdf.board.be.body.repository.BodyAnalysisRepository;
import com.asdf.board.be.body.repository.GoalBodyRepository;
import com.asdf.board.be.body.repository.PhotoRepository;
import com.asdf.board.be.global.async.AsyncRunner;
import com.asdf.board.be.global.config.VitalityProperties;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.storage.PhotoStorage;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.function.Consumer;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

@Slf4j
@Service
@RequiredArgsConstructor
public class AnalysisService {

    private static final Set<BodyAnalysis.Status> COUNTED = Set.of(BodyAnalysis.Status.done, BodyAnalysis.Status.pending);
    private static final String TIMEOUT_MESSAGE = "분석이 오래 걸려 중단했어요. 잠시 후 다시 시도해 주세요.";

    private final BodyAnalysisRepository analysisRepository;
    private final PhotoRepository photoRepository;
    private final GoalBodyRepository goalBodyRepository;
    private final UserRepository userRepository;
    private final PhotoStorage storage;
    private final AccessGuard accessGuard;
    private final BodyAiClient aiClient;
    private final AsyncRunner asyncRunner;
    private final VitalityProperties properties;
    private final PlatformTransactionManager transactionManager;
    private final JsonMapper jsonMapper;
    private final Clock clock;

    @Transactional
    public AnalysisAcceptedDto request(Long userId, AnalysisRequest request) {
        accessGuard.requireOnboarded(userId);
        accessGuard.requireConsent(userId, UserConsent.ConsentType.body_photo, UserConsent.ConsentType.ai_processing);
        Photo front = ownPhoto(userId, request.photoId(), Photo.Side.front);
        Photo side = request.sidePhotoId() == null ? null : ownPhoto(userId, request.sidePhotoId(), Photo.Side.side);
        GoalBody goal = null;
        if (request.goalBodyId() != null) {
            goal = goalBodyRepository.findByIdAndUserId(request.goalBodyId(), userId)
                    .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
            if (goal.getStatus() != GoalBody.Status.done) {
                throw new ApiException(ErrorCode.GOAL_NOT_READY);
            }
        }
        requireCapacity(userId);
        return accepted(analysisRepository.save(BodyAnalysis.builder()
                .user(userRepository.getReferenceById(userId))
                .source(BodyAnalysis.Source.photo)
                .status(BodyAnalysis.Status.pending)
                .photo(front)
                .sidePhoto(side)
                .goalBody(goal)
                .build()), this::process);
    }

    @Transactional
    public AnalysisAcceptedDto requestText(Long userId, TextAnalysisRequest request) {
        accessGuard.requireOnboarded(userId);
        accessGuard.requireConsent(userId, UserConsent.ConsentType.ai_processing);
        String text = request.textInput().strip();
        if (text.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        requireCapacity(userId);
        return accepted(analysisRepository.save(BodyAnalysis.builder()
                .user(userRepository.getReferenceById(userId))
                .source(BodyAnalysis.Source.text)
                .status(BodyAnalysis.Status.pending)
                .textInput(text)
                .build()), this::processText);
    }

    private void requireCapacity(Long userId) {
        if (analysisRepository.existsByUserIdAndStatus(userId, BodyAnalysis.Status.pending)) {
            throw new ApiException(ErrorCode.ANALYSIS_IN_PROGRESS);
        }
        if (usedToday(userId) >= properties.analysis().dailyLimit()) {
            throw new ApiException(ErrorCode.ANALYSIS_QUOTA_EXCEEDED);
        }
    }

    private AnalysisAcceptedDto accepted(BodyAnalysis analysis, Consumer<Long> job) {
        analysisRepository.flush();
        Long analysisId = analysis.getId();
        asyncRunner.run(() -> job.accept(analysisId));
        return new AnalysisAcceptedDto(analysisId, "pending", properties.analysis().pollAfterMs(),
                Times.offset(analysis.getCreatedAt()));
    }

    public void processText(Long analysisId) {
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        String text = tx.execute(status -> analysisRepository.findById(analysisId)
                .filter(a -> a.getStatus() == BodyAnalysis.Status.pending && a.getSource() == BodyAnalysis.Source.text)
                .map(BodyAnalysis::getTextInput)
                .orElse(null));
        if (text == null) {
            return;
        }
        BodyAiClient.TextSummary result;
        try {
            result = aiClient.summarizeText(text);
        } catch (RuntimeException e) {
            log.error("글 분석 실패 analysis={}", analysisId, e);
            result = new BodyAiClient.TextSummary(false, null, "분석에 실패했어요. 잠시 후 다시 시도해 주세요.");
        }
        BodyAiClient.TextSummary finalResult = result;
        tx.executeWithoutResult(status -> analysisRepository.findById(analysisId)
                .filter(a -> a.getStatus() == BodyAnalysis.Status.pending)
                .ifPresent(a -> {
                    if (finalResult.ok()) {
                        a.setTextSummary(finalResult.summary());
                        a.setStatus(BodyAnalysis.Status.done);
                        a.setCompletedAt(LocalDateTime.now(clock));
                    } else {
                        fail(a, BodyAnalysis.ErrorCode.AI_FAILED, finalResult.errorMessage());
                    }
                    analysisRepository.flush();
                }));
    }

    @Transactional(readOnly = true)
    public AnalysisDto get(Long userId, Long analysisId) {
        accessGuard.requireOnboarded(userId);
        return toDto(analysisRepository.findByIdAndUserId(analysisId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND)));
    }

    @Transactional(readOnly = true)
    public AnalysisPageDto list(Long userId, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        Page<BodyAnalysis> result = analysisRepository.findByUserId(
                userId, PageParams.of(page, pageSize, Sort.by(Sort.Direction.DESC, "id")));
        List<AnalysisSummaryDto> items = result.getContent().stream()
                .map(a -> new AnalysisSummaryDto(
                        a.getId(), a.getStatus().name(), a.getSource().name(), a.getBalanceScore(), a.getBodyType(),
                        a.getGoalBody() == null ? null : a.getGoalBody().getId(), Times.offset(a.getCreatedAt())))
                .toList();
        return new AnalysisPageDto(items, page, pageSize, (int) result.getTotalElements());
    }

    @Transactional(readOnly = true)
    public AnalysisUsageDto usage(Long userId) {
        accessGuard.requireOnboarded(userId);
        int used = (int) usedToday(userId);
        int limit = properties.analysis().dailyLimit();
        return new AnalysisUsageDto(used, limit, Math.max(0, limit - used), Times.nextMidnight(clock));
    }

    public void process(Long analysisId) {
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        record Job(byte[] front, byte[] side, String goalSummary, String goalDescription) {
        }
        Job job = tx.execute(status -> analysisRepository.findById(analysisId)
                .filter(a -> a.getStatus() == BodyAnalysis.Status.pending && a.getPhoto() != null)
                .map(a -> new Job(
                        storage.get(a.getPhoto().getStorageKey()),
                        a.getSidePhoto() == null ? null : storage.get(a.getSidePhoto().getStorageKey()),
                        a.getGoalBody() == null ? null : a.getGoalBody().getSummary(),
                        a.getGoalBody() == null ? null : a.getGoalBody().getDescription()))
                .orElse(null));
        if (job == null) {
            return;
        }
        BodyAiClient.PhotoAnalysis result;
        try {
            result = aiClient.analyze(job.front(), job.side(), job.goalSummary(), job.goalDescription());
        } catch (RuntimeException e) {
            log.error("체형 분석 실패 analysis={}", analysisId, e);
            result = new BodyAiClient.PhotoAnalysis(false, "AI_FAILED", "분석에 실패했어요. 잠시 후 다시 시도해 주세요.",
                    null, null, null, null, List.of(), null);
        }
        BodyAiClient.PhotoAnalysis finalResult = result;
        tx.executeWithoutResult(status -> analysisRepository.findById(analysisId)
                .filter(a -> a.getStatus() == BodyAnalysis.Status.pending)
                .ifPresent(a -> {
                    apply(a, finalResult);
                    analysisRepository.flush();
                }));
    }

    @Transactional
    public int failTimedOut() {
        LocalDateTime limit = LocalDateTime.now(clock).minus(properties.analysis().timeout());
        var stuck = analysisRepository.findByStatusAndCreatedAtBefore(BodyAnalysis.Status.pending, limit);
        stuck.forEach(a -> fail(a, BodyAnalysis.ErrorCode.AI_TIMEOUT, TIMEOUT_MESSAGE));
        analysisRepository.flush();
        return stuck.size();
    }

    @Transactional
    public void cancelPending(Long userId, String message) {
        analysisRepository.findFirstByUserIdAndStatusOrderByIdDesc(userId, BodyAnalysis.Status.pending)
                .ifPresent(a -> fail(a, BodyAnalysis.ErrorCode.AI_FAILED, message));
    }

    private void apply(BodyAnalysis a, BodyAiClient.PhotoAnalysis r) {
        if (!r.ok()) {
            fail(a, BodyAnalysis.ErrorCode.valueOf(r.errorCode()), r.errorMessage());
            return;
        }
        MeasuresDto m = r.measures();
        a.setShoulderTiltDeg(m.shoulderTiltDeg());
        a.setPelvisTiltDeg(m.pelvisTiltDeg());
        a.setNeckForwardDeg(m.neckForwardDeg());
        a.setShoulderHipRatio(m.shoulderHipRatio());
        a.setTorsoLegRatio(m.torsoLegRatio());
        a.setUnavailableJson(toJson(m.unavailable()));
        a.setBalanceScore(r.balanceScore());
        a.setBodyType(r.bodyType());
        a.setMeasurementVersion(r.measurementVersion());
        a.setJudgementsJson(toJson(r.judgements()));
        if (r.comparison() != null) {
            a.setPriorityPartsJson(toJson(r.comparison().priorityParts()));
            a.setComparisonSummary(r.comparison().summary());
            a.setComparisonDetail(r.comparison().detail());
        }
        a.setStatus(BodyAnalysis.Status.done);
        a.setCompletedAt(LocalDateTime.now(clock));
    }

    private void fail(BodyAnalysis a, BodyAnalysis.ErrorCode code, String message) {
        a.setStatus(BodyAnalysis.Status.failed);
        a.setErrorCode(code);
        a.setErrorMessage(message);
        a.setCompletedAt(LocalDateTime.now(clock));
    }

    private long usedToday(Long userId) {
        return analysisRepository.countByUserIdAndStatusInAndCreatedAtGreaterThanEqual(
                userId, COUNTED, Times.startOfToday(clock));
    }

    private Photo ownPhoto(Long userId, Long photoId, Photo.Side side) {
        Photo photo = photoRepository.findByIdAndUserId(photoId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (photo.getType() != Photo.Type.current || photo.getSide() != side) {
            throw new ApiException(ErrorCode.PHOTO_TYPE_MISMATCH);
        }
        return photo;
    }

    private AnalysisDto toDto(BodyAnalysis a) {
        boolean done = a.getStatus() == BodyAnalysis.Status.done;
        boolean photoDone = done && a.getSource() == BodyAnalysis.Source.photo;
        MeasuresDto measures = photoDone
                ? new MeasuresDto(a.getShoulderTiltDeg(), a.getPelvisTiltDeg(), a.getNeckForwardDeg(),
                a.getShoulderHipRatio(), a.getTorsoLegRatio(),
                fromJson(a.getUnavailableJson(), new TypeReference<List<MeasureUnavailableDto>>() { }))
                : null;
        List<JudgementDto> judgements = photoDone
                ? fromJson(a.getJudgementsJson(), new TypeReference<List<JudgementDto>>() { })
                : List.of();
        GoalComparisonDto comparison = done && a.getComparisonSummary() != null
                ? new GoalComparisonDto(
                fromJson(a.getPriorityPartsJson(), new TypeReference<List<BodyPartDto>>() { }),
                a.getComparisonSummary(), a.getComparisonDetail())
                : null;
        return new AnalysisDto(
                a.getId(), a.getStatus().name(), a.getSource().name(),
                a.getErrorCode() == null ? null : a.getErrorCode().name(), a.getErrorMessage(),
                a.getPhoto() == null ? null : a.getPhoto().getId(),
                a.getSidePhoto() == null ? null : a.getSidePhoto().getId(),
                a.getGoalBody() == null ? null : a.getGoalBody().getId(),
                measures,
                done ? a.getBalanceScore() : null,
                done ? a.getMeasurementVersion() : null,
                photoDone ? a.getBodyType() : null,
                judgements, comparison,
                done && a.getSource() == BodyAnalysis.Source.text ? a.getTextSummary() : null,
                Times.offset(a.getCreatedAt()), Times.offset(a.getCompletedAt()));
    }

    private String toJson(Object value) {
        return jsonMapper.writeValueAsString(value);
    }

    private <T> List<T> fromJson(String json, TypeReference<List<T>> type) {
        return json == null ? List.of() : jsonMapper.readValue(json, type);
    }
}
