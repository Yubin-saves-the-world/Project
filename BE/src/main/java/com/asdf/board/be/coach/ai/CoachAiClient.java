package com.asdf.board.be.coach.ai;

import java.util.List;

public interface CoachAiClient {

    Reply ask(Context context, String question);

    record Context(
            String analysisSummary,
            String goalSummary,
            int workoutsLast7Days,
            Long todayRoutineId,
            List<ItemView> todayItems) {
    }

    record ItemView(Long itemId, Long exerciseId, String exerciseName, String targetPart, int difficulty,
                    int sets, int reps, Long alternativeExerciseId) {
    }

    record Reply(String content, Proposal proposal) {
    }

    record Proposal(String summary, List<Change> changes) {
    }

    record Change(String action, Long routineItemId, Long exerciseId, Integer sets, Integer reps) {
    }
}
