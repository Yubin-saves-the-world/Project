package com.asdf.board.be.workout.service;

import com.asdf.board.be.body.dto.BodyPartDto;
import com.asdf.board.be.body.dto.JudgementDto;
import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.body.repository.BodyAnalysisRepository;
import com.asdf.board.be.global.enums.TargetPart;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.user.entity.UserProfile;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import com.asdf.board.be.workout.dto.RoutineDayDto;
import com.asdf.board.be.workout.dto.RoutineDto;
import com.asdf.board.be.workout.dto.RoutineItemDto;
import com.asdf.board.be.workout.dto.RoutineListDto;
import com.asdf.board.be.workout.dto.RoutinePatchStatus;
import com.asdf.board.be.workout.dto.RoutineSummaryDto;
import com.asdf.board.be.workout.dto.RoutineTodayDto;
import com.asdf.board.be.workout.dto.RoutineWeekDto;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.entity.ExercisePrescription;
import com.asdf.board.be.workout.entity.Routine;
import com.asdf.board.be.workout.entity.RoutineItem;
import com.asdf.board.be.workout.entity.WorkoutLog;
import com.asdf.board.be.workout.repository.ExerciseRepository;
import com.asdf.board.be.workout.repository.RoutineItemRepository;
import com.asdf.board.be.workout.repository.RoutineRepository;
import com.asdf.board.be.workout.repository.WorkoutLogRepository;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

@Service
@RequiredArgsConstructor
public class RoutineService {

    private final RoutineRepository routineRepository;
    private final RoutineItemRepository itemRepository;
    private final ExerciseRepository exerciseRepository;
    private final WorkoutLogRepository workoutLogRepository;
    private final BodyAnalysisRepository analysisRepository;
    private final UserProfileRepository profileRepository;
    private final UserRepository userRepository;
    private final ExerciseService exerciseService;
    private final RoutinePlanner planner;
    private final AccessGuard accessGuard;
    private final JsonMapper jsonMapper;
    private final Clock clock;

    @Transactional
    public RoutineListDto create(Long userId, Long analysisId) {
        accessGuard.requireOnboarded(userId);
        BodyAnalysis analysis = analysisRepository.findByIdAndUserId(analysisId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (analysis.getStatus() != BodyAnalysis.Status.done) {
            throw new ApiException(ErrorCode.ANALYSIS_NOT_READY);
        }
        LocalDate today = LocalDate.now(clock);
        List<Long> replaced = routineRepository
                .findByUserIdAndScheduledDateGreaterThanEqualAndStatus(userId, today, Routine.Status.planned)
                .stream().map(Routine::getId).toList();
        if (!replaced.isEmpty()) {
            itemRepository.deleteByRoutineIds(replaced);
            routineRepository.deleteByIds(replaced);
        }

        UserProfile profile = profileRepository.findFirstByUserIdOrderByIdDesc(userId)
                .orElseThrow(ApiException.of(ErrorCode.ONBOARDING_REQUIRED));
        List<Exercise> active = exerciseRepository.findByIsActiveTrue();
        Map<TargetPart, List<Exercise>> byPart = active.stream().collect(Collectors.groupingBy(
                Exercise::getTargetPart, () -> new EnumMap<>(TargetPart.class), Collectors.toList()));
        Map<Long, ExercisePrescription> prescriptions = exerciseService.prescriptions(
                active.stream().map(Exercise::getId).toList(), profile.getExperienceLevel());
        Set<LocalDate> taken = routineRepository.findByUserIdAndScheduledDateBetween(userId, today, today.plusDays(6))
                .stream().map(Routine::getScheduledDate).collect(Collectors.toSet());

        List<Routine> created = new ArrayList<>();
        Map<Long, List<RoutineItem>> itemsByRoutine = new HashMap<>();
        for (RoutinePlanner.PlannedDay day : planner.plan(profile, priorityParts(analysis), byPart, prescriptions)) {
            LocalDate date = today.plusDays(day.dayOffset());
            if (taken.contains(date)) {
                continue;
            }
            Routine routine = routineRepository.save(Routine.builder()
                    .user(userRepository.getReferenceById(userId))
                    .analysis(analysis)
                    .scheduledDate(date)
                    .title(day.title())
                    .targetPart(day.part())
                    .estimatedMinutes(day.estimatedMinutes())
                    .build());
            List<RoutineItem> items = new ArrayList<>();
            int order = 1;
            for (RoutinePlanner.PlannedItem item : day.items()) {
                items.add(itemRepository.save(RoutineItem.builder()
                        .routine(routine).exercise(item.exercise()).orderNo(order++)
                        .targetSets(item.sets()).targetReps(item.reps()).reason(item.reason()).build()));
            }
            created.add(routine);
            itemsByRoutine.put(routine.getId(), items);
        }
        routineRepository.flush();
        List<RoutineDto> dtos = created.stream()
                .map(r -> toDto(r, itemsByRoutine.get(r.getId()), Map.of(), prescriptions)).toList();
        return new RoutineListDto(analysisId, dtos);
    }

    @Transactional(readOnly = true)
    public RoutineDto get(Long userId, Long routineId) {
        accessGuard.requireOnboarded(userId);
        Routine routine = routineRepository.findByIdAndUserId(routineId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        return detail(userId, routine);
    }

    @Transactional
    public RoutineDto changeStatus(Long userId, Long routineId, RoutinePatchStatus status) {
        accessGuard.requireOnboarded(userId);
        Routine routine = routineRepository.findByIdAndUserId(routineId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (routine.getStatus() == Routine.Status.done) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        if (status == RoutinePatchStatus.planned && routine.getScheduledDate().isBefore(LocalDate.now(clock))) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        routine.setStatus(status == RoutinePatchStatus.skipped ? Routine.Status.skipped : Routine.Status.planned);
        routineRepository.flush();
        return detail(userId, routine);
    }

    @Transactional(readOnly = true)
    public RoutineTodayDto today(Long userId, LocalDate date) {
        accessGuard.requireOnboarded(userId);
        LocalDate target = date == null ? LocalDate.now(clock) : date;
        return routineRepository.findByUserIdAndScheduledDate(userId, target)
                .map(r -> new RoutineTodayDto(target, false, detail(userId, r)))
                .orElseGet(() -> new RoutineTodayDto(target, true, null));
    }

    @Transactional(readOnly = true)
    public RoutineWeekDto weekly(Long userId, LocalDate weekStart) {
        accessGuard.requireOnboarded(userId);
        LocalDate monday = weekStart == null
                ? LocalDate.now(clock).with(DayOfWeek.MONDAY) : weekStart;
        if (monday.getDayOfWeek() != DayOfWeek.MONDAY) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        List<Routine> routines = routineRepository.findByUserIdAndScheduledDateBetween(userId, monday, monday.plusDays(6));
        Map<LocalDate, Routine> byDate = routines.stream().collect(Collectors.toMap(Routine::getScheduledDate, r -> r));
        Map<Long, List<RoutineItem>> items = itemsOf(routines);
        Map<Long, Set<Long>> done = doneExercises(routines);
        List<RoutineDayDto> days = new ArrayList<>();
        for (int i = 0; i < 7; i++) {
            LocalDate date = monday.plusDays(i);
            Routine routine = byDate.get(date);
            RoutineSummaryDto summary = routine == null ? null : new RoutineSummaryDto(
                    routine.getId(), routine.getScheduledDate(), routine.getTitle(), routine.getTargetPart().name(),
                    routine.getEstimatedMinutes(), routine.getStatus().name(),
                    items.getOrDefault(routine.getId(), List.of()).size(),
                    (int) items.getOrDefault(routine.getId(), List.of()).stream()
                            .filter(it -> done.getOrDefault(routine.getId(), Set.of()).contains(it.getExercise().getId())).count());
            days.add(new RoutineDayDto(date, routine == null, summary));
        }
        return new RoutineWeekDto(monday, days);
    }

    @Transactional(readOnly = true)
    public RoutineDto detail(Long userId, Routine routine) {
        List<Routine> single = List.of(routine);
        Map<Long, List<RoutineItem>> items = itemsOf(single);
        Set<Long> exerciseIds = items.values().stream().flatMap(Collection::stream)
                .map(i -> i.getExercise().getId()).collect(Collectors.toSet());
        Map<Long, ExercisePrescription> prescriptions = exerciseService.prescriptions(
                exerciseIds, exerciseService.experience(userId));
        return toDto(routine, items.getOrDefault(routine.getId(), List.of()), doneExercises(single), prescriptions);
    }

    public Map<Long, Set<Long>> doneExercises(Collection<Routine> routines) {
        Map<Long, Set<Long>> done = new HashMap<>();
        if (routines.isEmpty()) {
            return done;
        }
        workoutLogRepository.findByRoutineIdInAndStatus(
                        routines.stream().map(Routine::getId).toList(), WorkoutLog.Status.completed)
                .forEach(log -> done.computeIfAbsent(log.getRoutine().getId(), k -> new HashSet<>())
                        .add(log.getExercise().getId()));
        return done;
    }

    private Map<Long, List<RoutineItem>> itemsOf(Collection<Routine> routines) {
        Map<Long, List<RoutineItem>> result = new HashMap<>();
        if (!routines.isEmpty()) {
            itemRepository.findWithExercise(routines.stream().map(Routine::getId).toList())
                    .forEach(i -> result.computeIfAbsent(i.getRoutine().getId(), k -> new ArrayList<>()).add(i));
        }
        return result;
    }

    private RoutineDto toDto(
            Routine routine, List<RoutineItem> items, Map<Long, Set<Long>> done,
            Map<Long, ExercisePrescription> prescriptions) {
        Set<Long> doneIds = done.getOrDefault(routine.getId(), Set.of());
        List<RoutineItemDto> itemDtos = items.stream().map(i -> new RoutineItemDto(
                i.getId(), i.getOrderNo(),
                ExerciseService.summary(i.getExercise(), prescriptions.get(i.getExercise().getId())),
                i.getTargetSets(), i.getTargetReps(), i.getTargetWeightKg(),
                RoutinePlanner.restSec(i.getExercise()), i.getReason(),
                doneIds.contains(i.getExercise().getId()))).toList();
        return new RoutineDto(
                routine.getId(), routine.getAnalysis().getId(), routine.getScheduledDate(), routine.getTitle(),
                routine.getTargetPart().name(), routine.getEstimatedMinutes(), routine.getStatus().name(), itemDtos);
    }

    List<TargetPart> priorityParts(BodyAnalysis analysis) {
        Set<TargetPart> parts = new LinkedHashSet<>();
        if (analysis.getPriorityPartsJson() != null) {
            List<BodyPartDto> priority = jsonMapper.readValue(
                    analysis.getPriorityPartsJson(), new TypeReference<List<BodyPartDto>>() { });
            priority.forEach(p -> parts.add(TargetPart.valueOf(p.part())));
        }
        if (parts.isEmpty() && analysis.getJudgementsJson() != null) {
            List<JudgementDto> judgements = jsonMapper.readValue(
                    analysis.getJudgementsJson(), new TypeReference<List<JudgementDto>>() { });
            for (JudgementDto j : judgements) {
                if (!"caution".equals(j.level())) {
                    continue;
                }
                switch (j.item()) {
                    case "shoulder_tilt" -> { parts.add(TargetPart.shoulder); parts.add(TargetPart.back); }
                    case "pelvis_tilt" -> { parts.add(TargetPart.core); parts.add(TargetPart.leg); }
                    case "neck_forward" -> { parts.add(TargetPart.back); parts.add(TargetPart.shoulder); }
                    default -> { }
                }
            }
        }
        return new ArrayList<>(parts);
    }
}
