package com.asdf.board.be;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.body.repository.BodyAnalysisRepository;
import com.asdf.board.be.support.ApiTestBase;
import java.time.Duration;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class Phase2aApiTest extends ApiTestBase {

    @Autowired BodyAnalysisRepository analysisRepository;

    private long finishedWorkout(TestUser user, long exerciseId, String... weightReps) throws Exception {
        long log = readId(postAs(user, "/api/workout-logs", "{\"exercise_id\":" + exerciseId + "}")
                .andExpect(status().is2xxSuccessful()), "$.log_id");
        int no = 1;
        for (String set : weightReps) {
            String[] parts = set.split("x");
            postAs(user, "/api/workout-logs/" + log + "/sets",
                    "{\"client_set_id\":\"%s\",\"set_no\":%d,\"weight_kg\":%s,\"reps\":%s}"
                            .formatted(UUID.randomUUID(), no++, parts[0], parts[1])).andExpect(status().isCreated());
        }
        advance(Duration.ofMinutes(5));
        patchAs(user, "/api/workout-logs/" + log + "/complete", "{}").andExpect(status().isOk());
        return log;
    }

    @Test
    void allergiesAreDeduplicatedIgnoringWhitespaceAndLimited() throws Exception {
        TestUser user = newUser(true);
        getAs(user, "/api/users/me/allergies").andExpect(status().isOk()).andExpect(jsonPath("$.items").isEmpty());
        long id = readId(postAs(user, "/api/users/me/allergies", "{\"item\":\"  땅콩  \"}")
                .andExpect(status().isCreated()).andExpect(jsonPath("$.item").value("땅콩"))
                .andExpect(jsonPath("$.created_at").isNotEmpty()), "$.allergy_id");
        postAs(user, "/api/users/me/allergies", "{\"item\":\"땅 콩\"}")
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("ALLERGY_DUPLICATED"));
        postAs(user, "/api/users/me/allergies", "{\"item\":\"   \"}").andExpect(status().isBadRequest());
        postAs(user, "/api/users/me/allergies", "{\"item\":\"" + "가".repeat(31) + "\"}").andExpect(status().isBadRequest());
        getAs(user, "/api/users/me/allergies").andExpect(jsonPath("$.items.length()").value(1));

        deleteAs(newUser(true), "/api/users/me/allergies/" + id).andExpect(status().isNotFound());
        deleteAs(user, "/api/users/me/allergies/" + id).andExpect(status().isNoContent());
        deleteAs(user, "/api/users/me/allergies/" + id).andExpect(status().isNotFound());

        for (int i = 0; i < 50; i++) {
            postAs(user, "/api/users/me/allergies", "{\"item\":\"음식" + i + "\"}").andExpect(status().isCreated());
        }
        postAs(user, "/api/users/me/allergies", "{\"item\":\"하나더\"}")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        getAs(newUser(false), "/api/users/me/allergies").andExpect(status().isForbidden());
        getAs(null, "/api/users/me/allergies").andExpect(status().isUnauthorized());
    }

    @Test
    void profileHistoryIsNewestFirstAndEmptyBeforeRegistration() throws Exception {
        TestUser fresh = newUser(false);
        getAs(fresh, "/api/users/me/profile/history").andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isEmpty()).andExpect(jsonPath("$.total").value(0))
                .andExpect(jsonPath("$.page").value(1)).andExpect(jsonPath("$.page_size").value(20));

        TestUser user = newUser(true);
        patchAs(user, "/api/users/me/profile", "{\"weight_kg\":72.0}").andExpect(status().isOk());
        patchAs(user, "/api/users/me/profile", "{\"weight_kg\":71.0}").andExpect(status().isOk());
        getAs(user, "/api/users/me/profile/history").andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(3))
                .andExpect(jsonPath("$.items[0].weight_kg").value(71.0))
                .andExpect(jsonPath("$.items[2].weight_kg").value(73.5));
        getAs(user, "/api/users/me/profile/history?page=2&page_size=2").andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1)).andExpect(jsonPath("$.items[0].weight_kg").value(73.5));
        getAs(user, "/api/users/me/profile/history?page=0").andExpect(status().isBadRequest());
        getAs(user, "/api/users/me/profile/history?page_size=51").andExpect(status().isBadRequest());
    }

    @Test
    void streakCountsConsecutiveDaysAndKeepsYesterday() throws Exception {
        TestUser user = newUser(true);
        getAs(user, "/api/streaks").andExpect(status().isOk()).andExpect(jsonPath("$.current_streak").value(0))
                .andExpect(jsonPath("$.longest_streak").value(0)).andExpect(jsonPath("$.last_workout_date").doesNotExist());

        long exercise = firstExerciseId(user, "chest");
        finishedWorkout(user, exercise, "40x10");
        advance(Duration.ofDays(1));
        finishedWorkout(user, exercise, "40x10");
        advance(Duration.ofDays(1));
        finishedWorkout(user, exercise, "40x10");
        getAs(user, "/api/streaks").andExpect(jsonPath("$.current_streak").value(3))
                .andExpect(jsonPath("$.longest_streak").value(3))
                .andExpect(jsonPath("$.last_workout_date").value(LocalDate.now(clock).toString()));

        advance(Duration.ofDays(1));
        getAs(user, "/api/streaks").andExpect(jsonPath("$.current_streak").value(3));
        advance(Duration.ofDays(1));
        getAs(user, "/api/streaks").andExpect(jsonPath("$.current_streak").value(0))
                .andExpect(jsonPath("$.longest_streak").value(3));
        getAs(newUser(false), "/api/streaks").andExpect(status().isForbidden());
    }

    @Test
    void statsAggregateCompletedLogsOnly() throws Exception {
        TestUser user = newUser(true);
        long chest = firstExerciseId(user, "chest");
        long leg = firstExerciseId(user, "leg");
        finishedWorkout(user, chest, "60x10", "70x5");
        finishedWorkout(user, leg, "100x5");
        long aborted = readId(postAs(user, "/api/workout-logs", "{\"exercise_id\":" + firstExerciseId(user, "back") + "}")
                .andExpect(status().isCreated()), "$.log_id");
        postAs(user, "/api/workout-logs/" + aborted + "/sets",
                "{\"client_set_id\":\"%s\",\"set_no\":1,\"weight_kg\":400,\"reps\":1}".formatted(UUID.randomUUID()))
                .andExpect(status().isCreated());

        LocalDate today = LocalDate.now(clock);
        getAs(user, "/api/workout-logs/stats?start_date=" + today.minusDays(7) + "&end_date=" + today)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.workout_days").value(1))
                .andExpect(jsonPath("$.log_count").value(2))
                .andExpect(jsonPath("$.total_volume_kg").value(1450.0))
                .andExpect(jsonPath("$.volume_trend.length()").value(1))
                .andExpect(jsonPath("$.volume_trend[0].date").value(today.toString()))
                .andExpect(jsonPath("$.by_part.length()").value(2))
                .andExpect(jsonPath("$.best_weights[0].max_weight_kg").value(100.0))
                .andExpect(jsonPath("$.best_weights[1].max_weight_kg").value(70.0));
        getAs(user, "/api/workout-logs/stats?start_date=" + today.minusDays(400) + "&end_date=" + today)
                .andExpect(status().isBadRequest());
        getAs(user, "/api/workout-logs/stats?start_date=" + today + "&end_date=" + today.minusDays(1))
                .andExpect(status().isBadRequest());
        getAs(user, "/api/workout-logs/stats?start_date=" + today).andExpect(status().isBadRequest());
        getAs(user, "/api/workout-logs/stats?start_date=" + today.plusDays(10) + "&end_date=" + today.plusDays(11))
                .andExpect(jsonPath("$.log_count").value(0)).andExpect(jsonPath("$.total_volume_kg").value(0));
        getAs(newUser(false), "/api/workout-logs/stats?start_date=" + today + "&end_date=" + today)
                .andExpect(status().isForbidden());
    }

    @Test
    void routineCanBeSkippedButNotWhenDone() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        String routines = postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}")
                .andReturn().getResponse().getContentAsString();
        long first = ((Number) com.jayway.jsonpath.JsonPath.read(routines, "$.routines[0].routine_id")).longValue();
        long second = ((Number) com.jayway.jsonpath.JsonPath.read(routines, "$.routines[1].routine_id")).longValue();

        patchAs(user, "/api/routines/" + first, "{\"status\":\"skipped\"}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("skipped"));
        patchAs(user, "/api/routines/" + first, "{\"status\":\"skipped\"}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("skipped"));
        patchAs(user, "/api/routines/" + first, "{\"status\":\"planned\"}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("planned"));
        patchAs(user, "/api/routines/" + first, "{\"status\":\"planned\"}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("planned"));
        patchAs(user, "/api/routines/" + first, "{\"status\":\"skipped\"}").andExpect(status().isOk());
        patchAs(user, "/api/routines/" + first, "{\"status\":\"done\"}").andExpect(status().isBadRequest());
        patchAs(user, "/api/routines/" + first, "{}").andExpect(status().isBadRequest());
        patchAs(newUser(true), "/api/routines/" + second, "{\"status\":\"skipped\"}").andExpect(status().isNotFound());
        patchAs(user, "/api/routines/999999", "{\"status\":\"skipped\"}").andExpect(status().isNotFound());

        String items = getAs(user, "/api/routines/" + second).andReturn().getResponse().getContentAsString();
        long exercise = ((Number) com.jayway.jsonpath.JsonPath.read(items, "$.items[0].exercise.exercise_id")).longValue();
        for (int i = 0; i < 6; i++) {
            Number id = com.jayway.jsonpath.JsonPath.read(items, "$.items[" + i + "].exercise.exercise_id");
            long log = readId(postAs(user, "/api/workout-logs",
                    "{\"exercise_id\":%d,\"routine_id\":%d}".formatted(id.longValue(), second)).andExpect(status().is2xxSuccessful()), "$.log_id");
            postAs(user, "/api/workout-logs/" + log + "/sets",
                    "{\"client_set_id\":\"%s\",\"set_no\":1,\"weight_kg\":20,\"reps\":10}".formatted(UUID.randomUUID()));
            advance(Duration.ofMinutes(2));
            patchAs(user, "/api/workout-logs/" + log + "/complete", "{}");
            if (getAs(user, "/api/routines/" + second).andReturn().getResponse().getContentAsString().contains("\"status\":\"done\"")) {
                break;
            }
        }
        patchAs(user, "/api/routines/" + second, "{\"status\":\"skipped\"}")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        patchAs(user, "/api/routines/" + second, "{\"status\":\"planned\"}")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        if (exercise < 0) {
            throw new AssertionError();
        }
    }

    @Test
    void skippedRoutineOfAPastDayCannotBeRestored() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        String routines = postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}")
                .andReturn().getResponse().getContentAsString();
        long first = ((Number) com.jayway.jsonpath.JsonPath.read(routines, "$.routines[0].routine_id")).longValue();
        patchAs(user, "/api/routines/" + first, "{\"status\":\"skipped\"}").andExpect(status().isOk());
        advance(Duration.ofDays(1));
        patchAs(user, "/api/routines/" + first, "{\"status\":\"planned\"}")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        patchAs(user, "/api/routines/" + first, "{\"status\":\"skipped\"}").andExpect(status().isOk());
    }

    @Test
    void correctionExercisesFollowCautionJudgements() throws Exception {
        TestUser user = newUser(true);
        getAs(user, "/api/correction-exercises").andExpect(status().isOk())
                .andExpect(jsonPath("$.analysis_id").doesNotExist()).andExpect(jsonPath("$.items").isEmpty());

        long analysisId = doneAnalysis(user, false);
        BodyAnalysis analysis = analysisRepository.findById(analysisId).orElseThrow();
        analysis.setJudgementsJson("""
                [{"item":"shoulder_tilt","label":"어깨 기울기","value":3.5,"unit":"deg","level":"caution"},
                 {"item":"pelvis_tilt","label":"골반 기울기","value":0.5,"unit":"deg","level":"good"},
                 {"item":"neck_forward","label":"목","value":null,"unit":"deg","level":"unavailable","reason":"SIDE_PHOTO_MISSING"}]
                """);
        analysisRepository.flush();

        String body = getAs(user, "/api/correction-exercises").andExpect(status().isOk())
                .andExpect(jsonPath("$.analysis_id").value(analysisId))
                .andExpect(jsonPath("$.items.length()").value(3))
                .andExpect(jsonPath("$.items[0].target_issue").value("shoulder_tilt"))
                .andReturn().getResponse().getContentAsString();
        long correction = ((Number) com.jayway.jsonpath.JsonPath.read(body, "$.items[0].correction_id")).longValue();

        getAs(user, "/api/correction-exercises?target_issue=neck_forward").andExpect(status().isOk())
                .andExpect(jsonPath("$.analysis_id").value(analysisId))
                .andExpect(jsonPath("$.items[0].target_issue").value("neck_forward"));
        getAs(user, "/api/correction-exercises?target_issue=bogus").andExpect(status().isBadRequest());
        getAs(user, "/api/correction-exercises/" + correction).andExpect(status().isOk())
                .andExpect(jsonPath("$.correction_id").value(correction)).andExpect(jsonPath("$.method").isNotEmpty());
        getAs(user, "/api/correction-exercises/999999").andExpect(status().isNotFound());
        getAs(newUser(false), "/api/correction-exercises").andExpect(status().isForbidden());
    }

    @Test
    void textAnalysisProducesSummaryWithoutMeasuresAndCountsTowardQuota() throws Exception {
        TestUser user = newUser(true);
        long id = readId(postAs(user, "/api/body-analyses/text", "{\"text_input\":\"어깨가 한쪽으로 기울고 목이 앞으로 나와 있어요\"}")
                .andExpect(status().isAccepted()).andExpect(jsonPath("$.status").value("pending")), "$.analysis_id");
        getAs(user, "/api/body-analyses/" + id).andExpect(jsonPath("$.status").value("pending"));
        postAs(user, "/api/body-analyses/text", "{\"text_input\":\"또\"}")
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("ANALYSIS_IN_PROGRESS"));
        asyncRunner.drain();
        getAs(user, "/api/body-analyses/" + id).andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("done")).andExpect(jsonPath("$.source").value("text"))
                .andExpect(jsonPath("$.text_summary").isNotEmpty()).andExpect(jsonPath("$.measures").doesNotExist())
                .andExpect(jsonPath("$.balance_score").doesNotExist()).andExpect(jsonPath("$.body_type").doesNotExist())
                .andExpect(jsonPath("$.judgements").isEmpty()).andExpect(jsonPath("$.photo_id").doesNotExist());
        getAs(user, "/api/body-analyses/usage").andExpect(jsonPath("$.used").value(1));

        postAs(user, "/api/body-analyses/text", "{\"text_input\":\"\"}").andExpect(status().isBadRequest());
        postAs(user, "/api/body-analyses/text", "{\"text_input\":\"" + "가".repeat(501) + "\"}").andExpect(status().isBadRequest());
        postAs(user, "/api/body-analyses/text", "{\"text_input\":\"둘\"}").andExpect(status().isAccepted());
        asyncRunner.drain();
        postAs(user, "/api/body-analyses/text", "{\"text_input\":\"셋\"}").andExpect(status().isAccepted());
        asyncRunner.drain();
        postAs(user, "/api/body-analyses/text", "{\"text_input\":\"넷\"}")
                .andExpect(status().isTooManyRequests()).andExpect(jsonPath("$.code").value("ANALYSIS_QUOTA_EXCEEDED"));

        TestUser noConsent = newUser(true, true, false);
        postAs(noConsent, "/api/body-analyses/text", "{\"text_input\":\"안녕\"}")
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("CONSENT_REQUIRED"));
        postAs(newUser(false), "/api/body-analyses/text", "{\"text_input\":\"안녕\"}")
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("ONBOARDING_REQUIRED"));
    }
}
