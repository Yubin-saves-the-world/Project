package com.asdf.board.be.workout.service;

import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.global.enums.TargetPart;
import com.asdf.board.be.user.entity.UserProfile;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.entity.ExercisePrescription;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * 루틴 추천 규칙. AI는 부위(priorityParts)만 정하고, 종목·세트·횟수는 이 규칙이 DB의 종목에서 고른다.
 */
@Component
public class RoutinePlanner {

    public static final List<TargetPart> DEFAULT_ORDER = List.of(
            TargetPart.chest, TargetPart.back, TargetPart.leg, TargetPart.shoulder, TargetPart.arm, TargetPart.core);

    public record PlannedItem(Exercise exercise, int sets, int reps, int restSec, String reason) {
    }

    public record PlannedDay(int dayOffset, TargetPart part, String title, int estimatedMinutes, List<PlannedItem> items) {
    }

    public List<Integer> trainingDays(int weeklyFrequency) {
        int count = Math.max(1, Math.min(7, weeklyFrequency));
        Set<Integer> days = new LinkedHashSet<>();
        for (int i = 0; i < count; i++) {
            days.add((int) Math.floor(i * 7.0 / count));
        }
        return new ArrayList<>(days);
    }

    public List<TargetPart> partCycle(List<TargetPart> priority) {
        Set<TargetPart> ordered = new LinkedHashSet<>(priority);
        ordered.addAll(DEFAULT_ORDER);
        return new ArrayList<>(ordered);
    }

    public List<PlannedDay> plan(
            UserProfile profile, List<TargetPart> priority, Map<TargetPart, List<Exercise>> byPart,
            Map<Long, ExercisePrescription> prescriptions) {
        ExperienceLevel level = profile.getExperienceLevel();
        List<Integer> days = trainingDays(profile.getWeeklyFrequency());
        List<TargetPart> cycle = partCycle(priority);
        List<PlannedDay> result = new ArrayList<>();
        for (int i = 0; i < days.size(); i++) {
            TargetPart part = cycle.get(i % cycle.size());
            List<PlannedItem> items = pickItems(profile, part, priority.contains(part), byPart.getOrDefault(part, List.of()),
                    prescriptions, level);
            if (items.isEmpty()) {
                continue;
            }
            String title = priority.contains(part) ? label(part) + " 집중 루틴" : label(part) + " 루틴";
            result.add(new PlannedDay(days.get(i), part, title, estimatedMinutes(items), items));
        }
        return result;
    }

    private List<PlannedItem> pickItems(
            UserProfile profile, TargetPart part, boolean focus, List<Exercise> candidates,
            Map<Long, ExercisePrescription> prescriptions, ExperienceLevel level) {
        int maxDifficulty = switch (level) {
            case under3m -> 2;
            case under1y -> 3;
            case over1y -> 5;
        };
        int wanted = switch (level) {
            case under3m -> 3;
            case under1y -> 4;
            case over1y -> 5;
        };
        List<Exercise> chosen = candidates.stream()
                .filter(e -> e.getDifficulty() <= maxDifficulty)
                .sorted(Comparator.comparing(Exercise::getDifficulty).reversed().thenComparing(Exercise::getName))
                .limit(wanted)
                .toList();
        List<PlannedItem> items = new ArrayList<>();
        for (Exercise exercise : chosen) {
            ExercisePrescription p = prescriptions.get(exercise.getId());
            int min = p == null ? 2 : p.getMinSets();
            int max = p == null ? 4 : p.getMaxSets();
            int sets = switch (level) {
                case under3m -> min;
                case under1y -> (int) Math.ceil((min + max) / 2.0);
                case over1y -> max;
            };
            items.add(new PlannedItem(exercise, sets, reps(profile.getGoalType()),
                    restSec(exercise),
                    focus ? "분석 결과 집중 부위(" + label(part) + ")를 위한 운동입니다." : "전체 균형을 위한 " + label(part) + " 운동입니다."));
        }
        return items;
    }

    static int reps(UserProfile.GoalType goal) {
        return switch (goal) {
            case muscle -> 10;
            case diet -> 15;
            case posture -> 12;
        };
    }

    public static int restSec(Exercise exercise) {
        return exercise.getDifficulty() >= 3 ? 90 : 60;
    }

    static int estimatedMinutes(List<PlannedItem> items) {
        int seconds = 0;
        for (PlannedItem item : items) {
            seconds += item.sets() * (45 + item.restSec());
        }
        return 5 + (int) Math.ceil(seconds / 60.0);
    }

    public static String label(TargetPart part) {
        return switch (part) {
            case chest -> "가슴";
            case back -> "등";
            case leg -> "하체";
            case shoulder -> "어깨";
            case arm -> "팔";
            case core -> "코어";
        };
    }
}
