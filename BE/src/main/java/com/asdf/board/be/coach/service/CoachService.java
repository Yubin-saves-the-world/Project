package com.asdf.board.be.coach.service;

import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.body.entity.GoalBody;
import com.asdf.board.be.body.repository.BodyAnalysisRepository;
import com.asdf.board.be.body.repository.GoalBodyRepository;
import com.asdf.board.be.coach.ai.CoachAiClient;
import com.asdf.board.be.coach.dto.AiUsageDto;
import com.asdf.board.be.coach.dto.ChatMessageDto;
import com.asdf.board.be.coach.dto.ChatMessagePageDto;
import com.asdf.board.be.coach.dto.ChatResponseDto;
import com.asdf.board.be.coach.dto.RoutineSuggestionDto;
import com.asdf.board.be.coach.dto.SuggestionChangeDto;
import com.asdf.board.be.coach.dto.SuggestionConfirmedDto;
import com.asdf.board.be.coach.entity.AiChatMessage;
import com.asdf.board.be.coach.entity.RoutineSuggestion;
import com.asdf.board.be.coach.repository.AiChatMessageRepository;
import com.asdf.board.be.coach.repository.RoutineSuggestionRepository;
import com.asdf.board.be.global.config.VitalityProperties;
import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import com.asdf.board.be.workout.dto.ExerciseSummaryDto;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.entity.Routine;
import com.asdf.board.be.workout.entity.RoutineItem;
import com.asdf.board.be.workout.entity.WorkoutLog;
import com.asdf.board.be.workout.repository.ExerciseRepository;
import com.asdf.board.be.workout.repository.RoutineItemRepository;
import com.asdf.board.be.workout.repository.RoutineRepository;
import com.asdf.board.be.workout.repository.WorkoutLogRepository;
import com.asdf.board.be.workout.service.ExerciseService;
import com.asdf.board.be.workout.service.RoutineService;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
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
public class CoachService {

    private static final Duration SUGGESTION_TTL = Duration.ofHours(24);
    private static final Set<String> ACTIONS = Set.of("replace", "add", "remove");

    private final AiChatMessageRepository messageRepository;
    private final RoutineSuggestionRepository suggestionRepository;
    private final BodyAnalysisRepository analysisRepository;
    private final GoalBodyRepository goalBodyRepository;
    private final WorkoutLogRepository workoutLogRepository;
    private final RoutineRepository routineRepository;
    private final RoutineItemRepository itemRepository;
    private final ExerciseRepository exerciseRepository;
    private final ExerciseService exerciseService;
    private final RoutineService routineService;
    private final UserRepository userRepository;
    private final AccessGuard accessGuard;
    private final CoachAiClient aiClient;
    private final VitalityProperties properties;
    private final PlatformTransactionManager transactionManager;
    private final JsonMapper jsonMapper;
    private final Clock clock;

    public ChatResponseDto ask(Long userId, String content) {
        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        CoachAiClient.Context context = tx.execute(status -> {
            accessGuard.requireOnboarded(userId);
            accessGuard.requireConsent(userId, UserConsent.ConsentType.ai_processing);
            if (usedToday(userId) >= limit()) {
                throw new ApiException(ErrorCode.AI_QUOTA_EXCEEDED);
            }
            return buildContext(userId);
        });

        String question = content.strip();
        CoachAiClient.Reply reply;
        try {
            reply = aiClient.ask(context, question);
        } catch (RuntimeException e) {
            log.error("AI 코치 호출 실패 user={}", userId, e);
            throw new ApiException(ErrorCode.AI_UNAVAILABLE);
        }
        return tx.execute(status -> save(userId, question, reply));
    }

    @Transactional(readOnly = true)
    public ChatMessagePageDto list(Long userId, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        Page<AiChatMessage> result = messageRepository.findByUserId(
                userId, PageParams.of(page, pageSize, Sort.by(Sort.Direction.DESC, "id")));
        List<Long> ids = result.getContent().stream().map(AiChatMessage::getId).toList();
        Map<Long, RoutineSuggestion> suggestions = new HashMap<>();
        if (!ids.isEmpty()) {
            suggestionRepository.findByMessageIdIn(ids).forEach(s -> suggestions.put(s.getMessage().getId(), s));
        }
        return new ChatMessagePageDto(
                result.getContent().stream().map(m -> message(m, suggestions.get(m.getId()))).toList(),
                page, pageSize, (int) result.getTotalElements());
    }

    @Transactional(readOnly = true)
    public AiUsageDto usage(Long userId) {
        accessGuard.requireOnboarded(userId);
        int used = (int) usedToday(userId);
        int limit = limit();
        return new AiUsageDto(used, limit, Math.max(0, limit - used),
                Times.nextMidnight(clock));
    }

    @Transactional
    public SuggestionConfirmedDto confirm(Long userId, Long suggestionId, boolean confirmed) {
        accessGuard.requireOnboarded(userId);
        RoutineSuggestion suggestion = suggestionRepository.findByIdAndUserId(suggestionId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (suggestion.getStatus() != RoutineSuggestion.Status.pending) {
            throw new ApiException(ErrorCode.SUGGESTION_ALREADY_HANDLED);
        }
        LocalDateTime now = LocalDateTime.now(clock);
        if (!suggestion.getExpiresAt().isAfter(now)) {
            throw new ApiException(ErrorCode.SUGGESTION_EXPIRED);
        }
        if (!confirmed) {
            suggestion.setStatus(RoutineSuggestion.Status.dismissed);
            suggestion.setHandledAt(now);
            return new SuggestionConfirmedDto(suggestion.getId(), "dismissed", null);
        }
        Routine routine = apply(userId, changesOf(suggestion));
        suggestion.setStatus(RoutineSuggestion.Status.applied);
        suggestion.setHandledAt(now);
        suggestionRepository.flush();
        return new SuggestionConfirmedDto(suggestion.getId(), "applied",
                routineService.detail(userId, routine));
    }

    private Routine apply(Long userId, List<SuggestionChangeDto> changes) {
        LocalDate today = LocalDate.now(clock);
        Routine result = null;
        for (SuggestionChangeDto change : changes) {
            Routine routine;
            RoutineItem item = null;
            if (change.routineItemId() != null) {
                item = itemRepository.findById(change.routineItemId()).orElseThrow(ApiException.of(ErrorCode.SUGGESTION_EXPIRED));
                routine = item.getRoutine();
            } else {
                routine = routineRepository.findByUserIdAndScheduledDateGreaterThanEqualAndStatus(userId, today, Routine.Status.planned)
                        .stream().min(Comparator.comparing(Routine::getScheduledDate))
                        .orElseThrow(ApiException.of(ErrorCode.SUGGESTION_EXPIRED));
            }
            if (!routine.getUser().getId().equals(userId) || routine.getStatus() != Routine.Status.planned
                    || routine.getScheduledDate().isBefore(today)) {
                throw new ApiException(ErrorCode.SUGGESTION_EXPIRED);
            }
            switch (change.action()) {
                case "replace" -> {
                    item.setExercise(exercise(change));
                    item.setTargetSets(change.targetSets());
                    item.setTargetReps(change.targetReps());
                }
                case "remove" -> {
                    if (itemRepository.findByRoutineIdOrderByOrderNoAsc(routine.getId()).size() > 1) {
                        itemRepository.delete(item);
                        itemRepository.flush();
                    }
                }
                case "add" -> {
                    int next = itemRepository.findByRoutineIdOrderByOrderNoAsc(routine.getId()).stream()
                            .mapToInt(RoutineItem::getOrderNo).max().orElse(0) + 1;
                    itemRepository.save(RoutineItem.builder().routine(routine).exercise(exercise(change)).orderNo(next)
                            .targetSets(change.targetSets()).targetReps(change.targetReps())
                            .reason("AI 코치 제안").build());
                }
                default -> throw new ApiException(ErrorCode.SUGGESTION_EXPIRED);
            }
            if (result == null) {
                result = routine;
            }
        }
        itemRepository.flush();
        if (result == null) {
            throw new ApiException(ErrorCode.SUGGESTION_EXPIRED);
        }
        return result;
    }

    private Exercise exercise(SuggestionChangeDto change) {
        return exerciseRepository.findById(change.exercise().exerciseId())
                .filter(e -> Boolean.TRUE.equals(e.getIsActive()))
                .orElseThrow(ApiException.of(ErrorCode.SUGGESTION_EXPIRED));
    }

    private ChatResponseDto save(Long userId, String content, CoachAiClient.Reply reply) {
        userRepository.findByIdForUpdate(userId).orElseThrow(ApiException.of(ErrorCode.UNAUTHORIZED));
        if (usedToday(userId) >= limit()) {
            throw new ApiException(ErrorCode.AI_QUOTA_EXCEEDED);
        }
        AiChatMessage question = messageRepository.save(AiChatMessage.builder()
                .user(userRepository.getReferenceById(userId)).role(AiChatMessage.Role.user).content(content).build());
        AiChatMessage answer = messageRepository.save(AiChatMessage.builder()
                .user(userRepository.getReferenceById(userId)).role(AiChatMessage.Role.assistant).content(reply.content()).build());
        messageRepository.flush();

        RoutineSuggestion suggestion = null;
        List<SuggestionChangeDto> changes = reply.proposal() == null ? List.of() : toChanges(reply.proposal().changes());
        if (!changes.isEmpty()) {
            suggestion = suggestionRepository.save(RoutineSuggestion.builder()
                    .user(userRepository.getReferenceById(userId)).message(answer)
                    .summary(truncate(reply.proposal().summary(), 100))
                    .changesJson(jsonMapper.writeValueAsString(changes))
                    .status(RoutineSuggestion.Status.pending)
                    .expiresAt(LocalDateTime.now(clock).plus(SUGGESTION_TTL)).build());
            suggestionRepository.flush();
        }
        ChatMessageDto replyDto = message(answer, suggestion);
        return new ChatResponseDto(message(question, null), replyDto, replyDto.suggestion(),
                (int) Math.max(0, limit() - usedToday(userId)));
    }

    private List<SuggestionChangeDto> toChanges(List<CoachAiClient.Change> raw) {
        Set<Long> ids = raw.stream().map(CoachAiClient.Change::exerciseId).filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Long, Exercise> exercises = exerciseRepository.findAllById(ids).stream()
                .collect(Collectors.toMap(Exercise::getId, e -> e));
        var prescriptions = exerciseService.prescriptions(ids, ExperienceLevel.under3m);
        List<SuggestionChangeDto> result = new ArrayList<>();
        for (CoachAiClient.Change c : raw) {
            if (!ACTIONS.contains(c.action())) {
                continue;
            }
            ExerciseSummaryDto summary = null;
            boolean remove = "remove".equals(c.action());
            if (!remove) {
                Exercise e = exercises.get(c.exerciseId());
                if (e == null) {
                    continue;
                }
                summary = ExerciseService.summary(e, prescriptions.get(e.getId()));
            }
            result.add(new SuggestionChangeDto(c.action(), c.routineItemId(), summary,
                    remove ? null : c.sets(), remove ? null : c.reps()));
        }
        return result;
    }

    private CoachAiClient.Context buildContext(Long userId) {
        LocalDate today = LocalDate.now(clock);
        String analysis = analysisRepository
                .findFirstByUserIdAndStatusOrderByIdDesc(userId, BodyAnalysis.Status.done)
                .map(a -> a.getComparisonSummary() != null ? a.getComparisonSummary() : a.getTextSummary()).orElse(null);
        String goal = goalBodyRepository.findFirstByUserIdOrderByIdDesc(userId)
                .filter(g -> g.getStatus() == GoalBody.Status.done).map(GoalBody::getSummary).orElse(null);
        int recent = (int) workoutLogRepository.countByUserIdAndWorkoutDateBetweenAndStatus(
                userId, today.minusDays(6), today, WorkoutLog.Status.completed);
        Optional<Routine> todayRoutine = routineRepository.findByUserIdAndScheduledDate(userId, today)
                .filter(r -> r.getStatus() == Routine.Status.planned);
        List<CoachAiClient.ItemView> items = null;
        if (todayRoutine.isPresent()) {
            List<RoutineItem> routineItems = itemRepository.findByRoutineIdOrderByOrderNoAsc(todayRoutine.get().getId());
            Set<Long> used = routineItems.stream().map(i -> i.getExercise().getId()).collect(Collectors.toSet());
            List<Exercise> active = exerciseRepository.findByIsActiveTrue();
            items = routineItems.stream().map(i -> {
                Exercise e = i.getExercise();
                Long alternative = active.stream()
                        .filter(o -> o.getTargetPart() == e.getTargetPart() && !used.contains(o.getId())
                                && o.getDifficulty() <= e.getDifficulty())
                        .min(Comparator.comparing(Exercise::getDifficulty).thenComparing(Exercise::getId))
                        .map(Exercise::getId).orElse(null);
                return new CoachAiClient.ItemView(i.getId(), e.getId(), e.getName(), e.getTargetPart().name(),
                        e.getDifficulty(), i.getTargetSets(), i.getTargetReps(), alternative);
            }).toList();
        }
        return new CoachAiClient.Context(analysis, goal, recent, todayRoutine.map(Routine::getId).orElse(null), items);
    }

    private ChatMessageDto message(AiChatMessage m, RoutineSuggestion suggestion) {
        return new ChatMessageDto(m.getId(), m.getRole().name(), m.getContent(), Times.offset(m.getCreatedAt()),
                suggestion == null ? null : suggestionDto(suggestion));
    }

    private RoutineSuggestionDto suggestionDto(RoutineSuggestion s) {
        return new RoutineSuggestionDto(s.getId(), s.getSummary(), changesOf(s), s.getStatus().name(), Times.offset(s.getExpiresAt()));
    }

    private List<SuggestionChangeDto> changesOf(RoutineSuggestion s) {
        return jsonMapper.readValue(s.getChangesJson(), new TypeReference<List<SuggestionChangeDto>>() { });
    }

    private long usedToday(Long userId) {
        return messageRepository.countByUserIdAndRoleAndCreatedAtGreaterThanEqual(
                userId, AiChatMessage.Role.user, Times.startOfToday(clock));
    }

    private int limit() {
        return properties.ai().coachDailyLimit();
    }

    private static String truncate(String value, int max) {
        return value.length() <= max ? value : value.substring(0, max);
    }
}
