package com.asdf.board.be.workout.service;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import com.asdf.board.be.workout.dto.ExerciseMiniDto;
import com.asdf.board.be.workout.dto.RoutineProgressDto;
import com.asdf.board.be.workout.dto.SetPatch;
import com.asdf.board.be.workout.dto.SetRequest;
import com.asdf.board.be.workout.dto.WorkoutCompleteRequest;
import com.asdf.board.be.workout.dto.WorkoutCompletedDto;
import com.asdf.board.be.workout.dto.WorkoutLogDetailDto;
import com.asdf.board.be.workout.dto.WorkoutLogItemDto;
import com.asdf.board.be.workout.dto.WorkoutLogPageDto;
import com.asdf.board.be.workout.dto.WorkoutSetDto;
import com.asdf.board.be.workout.dto.WorkoutStartRequest;
import com.asdf.board.be.workout.dto.WorkoutStartedDto;
import com.asdf.board.be.workout.dto.WorkoutSummaryDto;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.entity.Routine;
import com.asdf.board.be.workout.entity.RoutineItem;
import com.asdf.board.be.workout.entity.WorkoutLog;
import com.asdf.board.be.workout.entity.WorkoutSet;
import com.asdf.board.be.workout.repository.ExerciseRepository;
import com.asdf.board.be.workout.repository.RoutineItemRepository;
import com.asdf.board.be.workout.repository.RoutineRepository;
import com.asdf.board.be.workout.repository.WorkoutLogRepository;
import com.asdf.board.be.workout.repository.WorkoutSetRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class WorkoutService {

    private static final Duration ABORT_AFTER = Duration.ofHours(6);
    private static final int MAX_RANGE_DAYS = 92;

    private final WorkoutLogRepository logRepository;
    private final WorkoutSetRepository setRepository;
    private final ExerciseRepository exerciseRepository;
    private final RoutineRepository routineRepository;
    private final RoutineItemRepository itemRepository;
    private final UserRepository userRepository;
    private final AccessGuard accessGuard;
    private final Clock clock;

    public record StartResult(WorkoutStartedDto body, boolean created) {
    }

    @Transactional
    public StartResult start(Long userId, WorkoutStartRequest request) {
        accessGuard.requireOnboarded(userId);
        Exercise exercise = exerciseRepository.findById(request.exerciseId())
                .filter(Exercise::getIsActive).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        Routine routine = null;
        if (request.routineId() != null) {
            routine = routineRepository.findByIdAndUserId(request.routineId(), userId)
                    .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
            boolean inRoutine = itemRepository.findByRoutineIdOrderByOrderNoAsc(routine.getId()).stream()
                    .anyMatch(i -> i.getExercise().getId().equals(exercise.getId()));
            if (!inRoutine) {
                throw new ApiException(ErrorCode.VALIDATION_FAILED);
            }
        }
        LocalDateTime now = LocalDateTime.now(clock);
        var existing = logRepository.findByUserIdAndExerciseIdAndStatus(userId, exercise.getId(), WorkoutLog.Status.in_progress);
        if (existing.isPresent()) {
            WorkoutLog log = existing.get();
            if (Duration.between(log.getStartedAt(), now).compareTo(ABORT_AFTER) > 0) {
                log.setStatus(WorkoutLog.Status.aborted);
                logRepository.saveAndFlush(log);
            } else {
                return new StartResult(started(log, true), false);
            }
        }
        WorkoutLog log = logRepository.saveAndFlush(WorkoutLog.builder()
                .user(userRepository.getReferenceById(userId))
                .exercise(exercise)
                .routine(routine)
                .status(WorkoutLog.Status.in_progress)
                .workoutDate(now.toLocalDate())
                .startedAt(now)
                .build());
        return new StartResult(started(log, false), true);
    }

    @Transactional(readOnly = true)
    public WorkoutLogPageDto list(
            Long userId, LocalDate startDate, LocalDate endDate, WorkoutLog.Status status, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        if (endDate.isBefore(startDate) || ChronoUnit.DAYS.between(startDate, endDate) > MAX_RANGE_DAYS - 1) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        var pageable = PageParams.of(page, pageSize,
                Sort.by(Sort.Direction.DESC, "startedAt").and(Sort.by(Sort.Direction.DESC, "id")));
        Page<WorkoutLog> result = status == null
                ? logRepository.findByUserIdAndWorkoutDateBetween(userId, startDate, endDate, pageable)
                : logRepository.findByUserIdAndWorkoutDateBetweenAndStatus(userId, startDate, endDate, status, pageable);
        List<WorkoutLog> completed = logRepository.findByUserIdAndWorkoutDateBetweenAndStatus(
                userId, startDate, endDate, WorkoutLog.Status.completed);
        Set<WorkoutLog> loaded = new LinkedHashSet<>(result.getContent());
        loaded.addAll(completed);
        Map<Long, List<WorkoutSet>> sets = setsOf(loaded);
        List<WorkoutLogItemDto> items = result.getContent().stream().map(l -> item(l, sets.get(l.getId()))).toList();
        BigDecimal volume = BigDecimal.ZERO;
        int totalSets = 0;
        int duration = 0;
        Set<LocalDate> dates = new TreeSet<>();
        for (WorkoutLog log : completed) {
            List<WorkoutSet> done = doneSets(sets.get(log.getId()));
            totalSets += done.size();
            volume = volume.add(volume(done));
            duration += log.getDurationSec() == null ? 0 : log.getDurationSec();
            dates.add(log.getWorkoutDate());
        }
        WorkoutSummaryDto summary = new WorkoutSummaryDto(
                completed.size(), dates.size(), totalSets, volume, duration, new ArrayList<>(dates));
        return new WorkoutLogPageDto(summary, items, page, pageSize, (int) result.getTotalElements());
    }

    @Transactional(readOnly = true)
    public WorkoutLogDetailDto get(Long userId, Long logId) {
        accessGuard.requireOnboarded(userId);
        WorkoutLog log = own(userId, logId);
        List<WorkoutSet> sets = setRepository.findByLogIdOrderBySetNoAsc(logId);
        WorkoutLogItemDto i = item(log, sets);
        return new WorkoutLogDetailDto(i.logId(), i.exercise(), i.routineId(), i.workoutDate(), i.startedAt(),
                i.completedAt(), i.durationSec(), i.status(), i.setCount(), i.totalVolumeKg(), log.getMemo(),
                sets.stream().map(WorkoutService::toDto).toList());
    }

    @Transactional
    public void delete(Long userId, Long logId) {
        accessGuard.requireOnboarded(userId);
        WorkoutLog log = own(userId, logId);
        Long routineId = log.getRoutine() == null ? null : log.getRoutine().getId();
        setRepository.deleteByLogId(logId);
        logRepository.deleteRow(logId);
        if (routineId != null) {
            routineRepository.findById(routineId).ifPresent(r -> refreshRoutineStatus(r, progress(r)));
        }
    }

    @Transactional
    public SetResult addSet(Long userId, Long logId, SetRequest request) {
        accessGuard.requireOnboarded(userId);
        WorkoutLog log = own(userId, logId);
        var existing = setRepository.findByLogIdAndClientSetId(logId, request.clientSetId());
        if (existing.isPresent()) {
            return new SetResult(toDto(existing.get()), false);
        }
        if (log.getStatus() != WorkoutLog.Status.in_progress) {
            throw new ApiException(ErrorCode.WORKOUT_ALREADY_COMPLETED);
        }
        if (setRepository.existsByLogIdAndSetNo(logId, request.setNo())) {
            throw new ApiException(ErrorCode.SET_DUPLICATED);
        }
        WorkoutSet set = setRepository.saveAndFlush(WorkoutSet.builder()
                .log(log).clientSetId(request.clientSetId()).setNo(request.setNo())
                .weightKg(request.weightKg()).reps(request.reps()).restSec(request.restSec())
                .isDone(request.isDone() == null || request.isDone()).build());
        return new SetResult(toDto(set), true);
    }

    public record SetResult(WorkoutSetDto body, boolean created) {
    }

    @Transactional
    public WorkoutSetDto patchSet(Long userId, Long logId, Long setId, SetPatch request) {
        accessGuard.requireOnboarded(userId);
        own(userId, logId);
        WorkoutSet set = setRepository.findByIdAndLogId(setId, logId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (!set.getVersion().equals(request.version())) {
            throw new ApiException(ErrorCode.VERSION_CONFLICT);
        }
        if (request.weightKg() != null) {
            set.setWeightKg(request.weightKg());
        }
        if (request.reps() != null) {
            set.setReps(request.reps());
        }
        if (request.isDone() != null) {
            set.setIsDone(request.isDone());
        }
        if (request.restSec() != null) {
            set.setRestSec(request.restSec());
        }
        set.setVersion(set.getVersion() + 1);
        setRepository.saveAndFlush(set);
        return toDto(set);
    }

    @Transactional
    public void deleteSet(Long userId, Long logId, Long setId) {
        accessGuard.requireOnboarded(userId);
        own(userId, logId);
        WorkoutSet set = setRepository.findByIdAndLogId(setId, logId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        setRepository.delete(set);
        setRepository.flush();
    }

    @Transactional
    public WorkoutCompletedDto complete(Long userId, Long logId, WorkoutCompleteRequest request) {
        accessGuard.requireOnboarded(userId);
        WorkoutLog log = own(userId, logId);
        if (log.getStatus() != WorkoutLog.Status.in_progress) {
            throw new ApiException(ErrorCode.WORKOUT_ALREADY_COMPLETED);
        }
        List<WorkoutSet> done = doneSets(setRepository.findByLogIdOrderBySetNoAsc(logId));
        if (done.isEmpty()) {
            throw new ApiException(ErrorCode.WORKOUT_EMPTY);
        }
        LocalDateTime now = LocalDateTime.now(clock);
        int elapsed = (int) Math.max(1, Duration.between(log.getStartedAt(), now).getSeconds());
        int duration = request != null && request.durationSec() != null
                ? Math.min(request.durationSec(), elapsed) : elapsed;
        log.setStatus(WorkoutLog.Status.completed);
        log.setCompletedAt(now);
        log.setDurationSec(duration);
        if (request != null && request.memo() != null) {
            log.setMemo(request.memo());
        }
        logRepository.saveAndFlush(log);
        RoutineProgressDto progress = null;
        String routineStatus = null;
        Routine routine = log.getRoutine();
        if (routine != null) {
            progress = progress(routine);
            routineStatus = refreshRoutineStatus(routine, progress).name();
        }
        return new WorkoutCompletedDto(
                log.getId(), Times.offset(now), duration, volume(done), done.size(), progress, routineStatus);
    }

    @Transactional
    public int abortStale() {
        LocalDateTime limit = LocalDateTime.now(clock).minus(ABORT_AFTER);
        List<WorkoutLog> stale = logRepository.findByStatusAndStartedAtBefore(WorkoutLog.Status.in_progress, limit);
        stale.forEach(l -> l.setStatus(WorkoutLog.Status.aborted));
        logRepository.flush();
        return stale.size();
    }

    private Routine.Status refreshRoutineStatus(Routine routine, RoutineProgressDto progress) {
        if (routine.getStatus() == Routine.Status.skipped) {
            return routine.getStatus();
        }
        boolean allDone = progress.total() > 0 && progress.done() >= progress.total();
        routine.setStatus(allDone ? Routine.Status.done : Routine.Status.planned);
        routineRepository.flush();
        return routine.getStatus();
    }

    private RoutineProgressDto progress(Routine routine) {
        List<RoutineItem> items = itemRepository.findByRoutineIdOrderByOrderNoAsc(routine.getId());
        Set<Long> done = logRepository.findByRoutineIdAndStatus(routine.getId(), WorkoutLog.Status.completed).stream()
                .map(l -> l.getExercise().getId()).collect(Collectors.toSet());
        int count = (int) items.stream().filter(i -> done.contains(i.getExercise().getId())).count();
        return new RoutineProgressDto(count, items.size());
    }

    private WorkoutLog own(Long userId, Long logId) {
        return logRepository.findByIdAndUserId(logId, userId).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
    }

    private Map<Long, List<WorkoutSet>> setsOf(Collection<WorkoutLog> logs) {
        Map<Long, List<WorkoutSet>> result = new HashMap<>();
        if (!logs.isEmpty()) {
            setRepository.findByLogIdIn(logs.stream().map(WorkoutLog::getId).toList())
                    .forEach(s -> result.computeIfAbsent(s.getLog().getId(), k -> new ArrayList<>()).add(s));
        }
        return result;
    }

    private static List<WorkoutSet> doneSets(List<WorkoutSet> sets) {
        return sets == null ? List.of() : sets.stream().filter(s -> Boolean.TRUE.equals(s.getIsDone())).toList();
    }

    private static BigDecimal volume(List<WorkoutSet> done) {
        return done.stream().map(s -> s.getWeightKg().multiply(BigDecimal.valueOf(s.getReps())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private WorkoutStartedDto started(WorkoutLog log, boolean resumed) {
        return new WorkoutStartedDto(
                log.getId(), log.getExercise().getId(), log.getRoutine() == null ? null : log.getRoutine().getId(),
                Times.offset(log.getStartedAt()), "in_progress", resumed);
    }

    private WorkoutLogItemDto item(WorkoutLog log, List<WorkoutSet> sets) {
        List<WorkoutSet> done = doneSets(sets);
        Exercise e = log.getExercise();
        return new WorkoutLogItemDto(
                log.getId(), new ExerciseMiniDto(e.getId(), e.getName(), e.getTargetPart().name()),
                log.getRoutine() == null ? null : log.getRoutine().getId(), log.getWorkoutDate(),
                Times.offset(log.getStartedAt()), Times.offset(log.getCompletedAt()), log.getDurationSec(),
                log.getStatus().name(), done.size(), volume(done));
    }

    private static WorkoutSetDto toDto(WorkoutSet s) {
        return new WorkoutSetDto(s.getId(), s.getClientSetId(), s.getSetNo(), s.getVersion(), s.getWeightKg(),
                s.getReps(), s.getRestSec(), s.getIsDone());
    }
}
