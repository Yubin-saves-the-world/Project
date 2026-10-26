package com.asdf.board.be.workout.service;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.user.service.AccessGuard;
import com.asdf.board.be.workout.dto.BestWeightDto;
import com.asdf.board.be.workout.dto.PartCountDto;
import com.asdf.board.be.workout.dto.StreakDto;
import com.asdf.board.be.workout.dto.VolumePointDto;
import com.asdf.board.be.workout.dto.WorkoutStatsDto;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.entity.WorkoutLog;
import com.asdf.board.be.workout.entity.WorkoutSet;
import com.asdf.board.be.workout.repository.WorkoutLogRepository;
import com.asdf.board.be.workout.repository.WorkoutSetRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class WorkoutStatsService {

    private static final int MAX_RANGE_DAYS = 366;

    private final WorkoutLogRepository logRepository;
    private final WorkoutSetRepository setRepository;
    private final AccessGuard accessGuard;
    private final Clock clock;

    @Transactional(readOnly = true)
    public StreakDto streak(Long userId) {
        accessGuard.requireOnboarded(userId);
        List<LocalDate> desc = logRepository.completedDates(userId);
        if (desc.isEmpty()) {
            return new StreakDto(0, 0, null);
        }
        Set<LocalDate> days = new TreeSet<>(desc);
        int longest = 0;
        int run = 0;
        LocalDate previous = null;
        for (LocalDate day : days) {
            run = previous != null && previous.plusDays(1).equals(day) ? run + 1 : 1;
            longest = Math.max(longest, run);
            previous = day;
        }
        LocalDate last = desc.get(0);
        LocalDate today = LocalDate.now(clock);
        int current = 0;
        if (!last.isBefore(today.minusDays(1))) {
            LocalDate cursor = last;
            while (days.contains(cursor)) {
                current++;
                cursor = cursor.minusDays(1);
            }
        }
        return new StreakDto(current, longest, last);
    }

    @Transactional(readOnly = true)
    public WorkoutStatsDto stats(Long userId, LocalDate startDate, LocalDate endDate) {
        accessGuard.requireOnboarded(userId);
        if (endDate.isBefore(startDate) || ChronoUnit.DAYS.between(startDate, endDate) > MAX_RANGE_DAYS - 1) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        List<WorkoutLog> logs = logRepository.findByUserIdAndWorkoutDateBetweenAndStatus(
                userId, startDate, endDate, WorkoutLog.Status.completed);
        Map<Long, List<WorkoutSet>> sets = new HashMap<>();
        if (!logs.isEmpty()) {
            setRepository.findByLogIdInAndIsDoneTrue(logs.stream().map(WorkoutLog::getId).toList())
                    .forEach(s -> sets.computeIfAbsent(s.getLog().getId(), k -> new ArrayList<>()).add(s));
        }
        BigDecimal total = BigDecimal.ZERO;
        Map<LocalDate, BigDecimal> perDay = new TreeMap<>();
        Map<String, Integer> perPart = new TreeMap<>();
        Map<Long, BestWeightDto> best = new HashMap<>();
        for (WorkoutLog log : logs) {
            Exercise exercise = log.getExercise();
            BigDecimal volume = BigDecimal.ZERO;
            for (WorkoutSet set : sets.getOrDefault(log.getId(), List.of())) {
                volume = volume.add(set.getWeightKg().multiply(BigDecimal.valueOf(set.getReps())));
                BestWeightDto current = best.get(exercise.getId());
                if (current == null || set.getWeightKg().compareTo(current.maxWeightKg()) > 0) {
                    best.put(exercise.getId(), new BestWeightDto(exercise.getId(), exercise.getName(), set.getWeightKg()));
                }
            }
            total = total.add(volume);
            perDay.merge(log.getWorkoutDate(), volume, BigDecimal::add);
            perPart.merge(exercise.getTargetPart().name(), 1, Integer::sum);
        }
        List<VolumePointDto> trend = perDay.entrySet().stream()
                .map(e -> new VolumePointDto(e.getKey(), e.getValue())).toList();
        List<PartCountDto> parts = perPart.entrySet().stream()
                .sorted(Map.Entry.<String, Integer>comparingByValue().reversed().thenComparing(Map.Entry.comparingByKey()))
                .map(e -> new PartCountDto(e.getKey(), e.getValue())).toList();
        List<BestWeightDto> bests = best.values().stream()
                .sorted(Comparator.comparing(BestWeightDto::maxWeightKg).reversed().thenComparing(BestWeightDto::exerciseId))
                .toList();
        return new WorkoutStatsDto(perDay.size(), logs.size(), total, trend, parts, bests);
    }
}
