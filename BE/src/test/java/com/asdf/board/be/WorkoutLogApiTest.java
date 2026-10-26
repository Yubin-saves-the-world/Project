package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.support.ApiTestBase;
import com.jayway.jsonpath.JsonPath;
import java.time.Duration;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.asdf.board.be.workout.service.WorkoutService;

class WorkoutLogApiTest extends ApiTestBase {

    @Autowired WorkoutService workoutService;

    private String uuid() {
        return java.util.UUID.randomUUID().toString();
    }

    private long start(TestUser user, long exerciseId, Long routineId) throws Exception {
        String body = routineId == null ? "{\"exercise_id\":" + exerciseId + "}"
                : "{\"exercise_id\":%d,\"routine_id\":%d}".formatted(exerciseId, routineId);
        return readId(postAs(user, "/api/workout-logs", body).andExpect(status().is2xxSuccessful()), "$.log_id");
    }

    private long addSet(TestUser user, long logId, int no, String weight, int reps) throws Exception {
        return readId(postAs(user, "/api/workout-logs/" + logId + "/sets",
                "{\"client_set_id\":\"%s\",\"set_no\":%d,\"weight_kg\":%s,\"reps\":%d}"
                        .formatted(uuid(), no, weight, reps)).andExpect(status().isCreated()), "$.set_id");
    }

    @Test
    void startsFreeWorkoutAndResumesInProgressOne() throws Exception {
        TestUser user = newUser(true);
        long exercise = firstExerciseId(user, "chest");
        long log = readId(postAs(user, "/api/workout-logs", "{\"exercise_id\":" + exercise + "}")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("in_progress"))
                .andExpect(jsonPath("$.resumed").value(false))
                .andExpect(jsonPath("$.routine_id").doesNotExist())
                .andExpect(jsonPath("$.started_at").isNotEmpty()), "$.log_id");
        postAs(user, "/api/workout-logs", "{\"exercise_id\":" + exercise + "}").andExpect(status().isOk())
                .andExpect(jsonPath("$.log_id").value(log)).andExpect(jsonPath("$.resumed").value(true));
        postAs(user, "/api/workout-logs", "{\"exercise_id\":999999}").andExpect(status().isNotFound());
        postAs(user, "/api/workout-logs", "{}").andExpect(status().isBadRequest());
        postAs(newUser(false), "/api/workout-logs", "{\"exercise_id\":1}").andExpect(status().isForbidden());
    }

    @Test
    void routineMustBeMineAndContainTheExercise() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        String routines = postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}")
                .andReturn().getResponse().getContentAsString();
        long routine = ((Number) JsonPath.read(routines, "$.routines[0].routine_id")).longValue();
        long inRoutine = ((Number) JsonPath.read(routines, "$.routines[0].items[0].exercise.exercise_id")).longValue();
        String otherPart = JsonPath.read(routines, "$.routines[0].target_part").equals("chest") ? "leg" : "chest";
        long outside = firstExerciseId(user, otherPart);
        postAs(user, "/api/workout-logs", "{\"exercise_id\":%d,\"routine_id\":%d}".formatted(outside, routine))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        postAs(newUser(true), "/api/workout-logs", "{\"exercise_id\":%d,\"routine_id\":%d}".formatted(inRoutine, routine))
                .andExpect(status().isNotFound());
        postAs(user, "/api/workout-logs", "{\"exercise_id\":%d,\"routine_id\":%d}".formatted(inRoutine, routine))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.routine_id").value(routine));
    }

    @Test
    void setsAreIdempotentAndValidated() throws Exception {
        TestUser user = newUser(true);
        long log = start(user, firstExerciseId(user, "back"), null);
        String id = uuid();
        String body = "{\"client_set_id\":\"%s\",\"set_no\":1,\"weight_kg\":60.5,\"reps\":10,\"rest_sec\":90}".formatted(id);
        long set = readId(postAs(user, "/api/workout-logs/" + log + "/sets", body).andExpect(status().isCreated())
                .andExpect(jsonPath("$.version").value(1)).andExpect(jsonPath("$.is_done").value(true))
                .andExpect(jsonPath("$.weight_kg").value(60.5)).andExpect(jsonPath("$.rest_sec").value(90)), "$.set_id");
        postAs(user, "/api/workout-logs/" + log + "/sets", body).andExpect(status().isOk())
                .andExpect(jsonPath("$.set_id").value(set));
        postAs(user, "/api/workout-logs/" + log + "/sets",
                "{\"client_set_id\":\"%s\",\"set_no\":1,\"weight_kg\":50,\"reps\":8}".formatted(uuid()))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("SET_DUPLICATED"));
        for (String bad : new String[] {
                "{\"client_set_id\":\"short\",\"set_no\":2,\"weight_kg\":10,\"reps\":5}",
                "{\"client_set_id\":\"%s\",\"set_no\":0,\"weight_kg\":10,\"reps\":5}".formatted(uuid()),
                "{\"client_set_id\":\"%s\",\"set_no\":2,\"weight_kg\":501,\"reps\":5}".formatted(uuid()),
                "{\"client_set_id\":\"%s\",\"set_no\":2,\"weight_kg\":10,\"reps\":0}".formatted(uuid()),
                "{\"client_set_id\":\"%s\",\"set_no\":2,\"weight_kg\":10,\"reps\":101}".formatted(uuid()),
                "{\"client_set_id\":\"%s\",\"set_no\":2,\"weight_kg\":10,\"reps\":5,\"rest_sec\":3601}".formatted(uuid())}) {
            postAs(user, "/api/workout-logs/" + log + "/sets", bad).andExpect(status().isBadRequest());
        }
        postAs(newUser(true), "/api/workout-logs/" + log + "/sets", body).andExpect(status().isNotFound());
    }

    @Test
    void patchUsesOptimisticVersion() throws Exception {
        TestUser user = newUser(true);
        long log = start(user, firstExerciseId(user, "leg"), null);
        long set = addSet(user, log, 1, "40", 12);
        patchAs(user, "/api/workout-logs/%d/sets/%d".formatted(log, set), "{\"version\":1,\"reps\":15,\"weight_kg\":42.5}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.version").value(2))
                .andExpect(jsonPath("$.reps").value(15)).andExpect(jsonPath("$.weight_kg").value(42.5));
        patchAs(user, "/api/workout-logs/%d/sets/%d".formatted(log, set), "{\"version\":1,\"reps\":9}")
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));
        patchAs(user, "/api/workout-logs/%d/sets/%d".formatted(log, set), "{\"reps\":9}").andExpect(status().isBadRequest());
        patchAs(user, "/api/workout-logs/%d/sets/%d".formatted(log, set), "{\"version\":2,\"is_done\":false}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.is_done").value(false))
                .andExpect(jsonPath("$.version").value(3));
        patchAs(user, "/api/workout-logs/%d/sets/999999".formatted(log), "{\"version\":1}").andExpect(status().isNotFound());
    }

    @Test
    void deletingSetKeepsOtherSetNumbers() throws Exception {
        TestUser user = newUser(true);
        long log = start(user, firstExerciseId(user, "arm"), null);
        long first = addSet(user, log, 1, "10", 10);
        addSet(user, log, 2, "10", 10);
        deleteAs(user, "/api/workout-logs/%d/sets/%d".formatted(log, first)).andExpect(status().isNoContent());
        deleteAs(user, "/api/workout-logs/%d/sets/%d".formatted(log, first)).andExpect(status().isNotFound());
        postAs(user, "/api/workout-logs/" + log + "/sets",
                "{\"client_set_id\":\"%s\",\"set_no\":1,\"weight_kg\":10,\"reps\":10}".formatted(uuid()))
                .andExpect(status().isCreated());
    }

    @Test
    void completeComputesDurationAndVolume() throws Exception {
        TestUser user = newUser(true);
        long log = start(user, firstExerciseId(user, "shoulder"), null);
        patchAs(user, "/api/workout-logs/" + log + "/complete", "{}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("WORKOUT_EMPTY"));
        addSet(user, log, 1, "20", 10);
        addSet(user, log, 2, "22.5", 8);
        postAs(user, "/api/workout-logs/" + log + "/sets",
                "{\"client_set_id\":\"%s\",\"set_no\":3,\"weight_kg\":100,\"reps\":5,\"is_done\":false}".formatted(uuid()))
                .andExpect(status().isCreated());
        advance(Duration.ofMinutes(30));
        patchAs(user, "/api/workout-logs/" + log + "/complete", "{\"duration_sec\":99999,\"memo\":\"좋았다\"}")
                .andExpect(status().isBadRequest());
        patchAs(user, "/api/workout-logs/" + log + "/complete", "{\"duration_sec\":21601}").andExpect(status().isBadRequest());
        patchAs(user, "/api/workout-logs/" + log + "/complete", "{\"duration_sec\":21000}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.duration_sec").value(org.hamcrest.Matchers.lessThanOrEqualTo(1805)))
                .andExpect(jsonPath("$.duration_sec").value(org.hamcrest.Matchers.greaterThanOrEqualTo(1800)))
                .andExpect(jsonPath("$.set_count").value(2))
                .andExpect(jsonPath("$.total_volume_kg").value(380.0))
                .andExpect(jsonPath("$.routine_progress").doesNotExist())
                .andExpect(jsonPath("$.routine_status").doesNotExist());
        patchAs(user, "/api/workout-logs/" + log + "/complete", "{}").andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("WORKOUT_ALREADY_COMPLETED"));
        postAs(user, "/api/workout-logs/" + log + "/sets",
                "{\"client_set_id\":\"%s\",\"set_no\":4,\"weight_kg\":10,\"reps\":5}".formatted(uuid()))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("WORKOUT_ALREADY_COMPLETED"));
        getAs(user, "/api/workout-logs/" + log).andExpect(jsonPath("$.status").value("completed"))
                .andExpect(jsonPath("$.set_count").value(2)).andExpect(jsonPath("$.total_volume_kg").value(380.0));
    }

    @Test
    void durationUsesTimerValueWhenShorterThanElapsed() throws Exception {
        TestUser user = newUser(true);
        long log = start(user, firstExerciseId(user, "core"), null);
        addSet(user, log, 1, "0", 20);
        advance(Duration.ofMinutes(10));
        patchAs(user, "/api/workout-logs/" + log + "/complete", "{\"duration_sec\":420}").andExpect(status().isOk())
                .andExpect(jsonPath("$.duration_sec").value(420));
    }

    @Test
    void finishingAllRoutineItemsMarksRoutineDoneAndDeletionReopensIt() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        String routines = postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}").andReturn()
                .getResponse().getContentAsString();
        long routine = ((Number) JsonPath.read(routines, "$.routines[0].routine_id")).longValue();
        int items = JsonPath.read(routines, "$.routines[0].items.length()");
        long lastLog = 0;
        for (int i = 0; i < items; i++) {
            long exercise = ((Number) JsonPath.read(routines, "$.routines[0].items[" + i + "].exercise.exercise_id")).longValue();
            long log = start(user, exercise, routine);
            addSet(user, log, 1, "30", 10);
            boolean last = i == items - 1;
            patchAs(user, "/api/workout-logs/" + log + "/complete", "{}").andExpect(status().isOk())
                    .andExpect(jsonPath("$.routine_progress.done").value(i + 1))
                    .andExpect(jsonPath("$.routine_progress.total").value(items))
                    .andExpect(jsonPath("$.routine_status").value(last ? "done" : "planned"));
            lastLog = log;
        }
        getAs(user, "/api/routines/" + routine).andExpect(jsonPath("$.status").value("done"))
                .andExpect(jsonPath("$.items[0].done").value(true));
        deleteAs(user, "/api/workout-logs/" + lastLog).andExpect(status().isNoContent());
        getAs(user, "/api/routines/" + routine).andExpect(jsonPath("$.status").value("planned"))
                .andExpect(jsonPath("$.items[" + (items - 1) + "].done").value(false));
        getAs(user, "/api/workout-logs/" + lastLog).andExpect(status().isNotFound());
    }

    @Test
    void listHasSummaryRangeAndPaging() throws Exception {
        TestUser user = newUser(true);
        long a = start(user, firstExerciseId(user, "chest"), null);
        addSet(user, a, 1, "50", 10);
        addSet(user, a, 2, "50", 8);
        patchAs(user, "/api/workout-logs/" + a + "/complete", "{}").andExpect(status().isOk());
        long b = start(user, firstExerciseId(user, "back"), null);
        addSet(user, b, 1, "30", 10);
        String today = LocalDate.now().toString();
        getAs(user, "/api/workout-logs?start_date=%s&end_date=%s".formatted(today, today)).andExpect(status().isOk())
                .andExpect(jsonPath("$.summary.log_count").value(1))
                .andExpect(jsonPath("$.summary.workout_days").value(1))
                .andExpect(jsonPath("$.summary.total_sets").value(2))
                .andExpect(jsonPath("$.summary.total_volume_kg").value(900.0))
                .andExpect(jsonPath("$.summary.workout_dates[0]").value(today))
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.items[0].log_id").value(b))
                .andExpect(jsonPath("$.items[0].status").value("in_progress"))
                .andExpect(jsonPath("$.items[0].completed_at").doesNotExist())
                .andExpect(jsonPath("$.items[1].exercise.name").isNotEmpty())
                .andExpect(jsonPath("$.total").value(2));
        getAs(user, "/api/workout-logs?start_date=%s&end_date=%s&status=in_progress".formatted(today, today))
                .andExpect(jsonPath("$.items.length()").value(1)).andExpect(jsonPath("$.items[0].log_id").value(b))
                .andExpect(jsonPath("$.summary.log_count").value(1));
        getAs(user, "/api/workout-logs?start_date=%s&end_date=%s&page_size=1&page=2".formatted(today, today))
                .andExpect(jsonPath("$.items.length()").value(1)).andExpect(jsonPath("$.items[0].log_id").value(a));
        getAs(user, "/api/workout-logs").andExpect(status().isBadRequest());
        getAs(user, "/api/workout-logs?start_date=%s&end_date=%s".formatted(today, LocalDate.now().minusDays(1)))
                .andExpect(status().isBadRequest());
        getAs(user, "/api/workout-logs?start_date=%s&end_date=%s".formatted(LocalDate.now().minusDays(92), today))
                .andExpect(status().isBadRequest());
        getAs(user, "/api/workout-logs?start_date=%s&end_date=%s".formatted(LocalDate.now().minusDays(91), today))
                .andExpect(status().isOk());
        getAs(user, "/api/workout-logs?start_date=%s&end_date=%s&status=bad".formatted(today, today))
                .andExpect(status().isBadRequest());
        getAs(newUser(true), "/api/workout-logs?start_date=%s&end_date=%s".formatted(today, today))
                .andExpect(jsonPath("$.total").value(0)).andExpect(jsonPath("$.summary.log_count").value(0));
    }

    @Test
    void staleInProgressLogIsAbortedAndSameExerciseStartsFresh() throws Exception {
        TestUser user = newUser(true);
        long exercise = firstExerciseId(user, "leg");
        long old = start(user, exercise, null);
        advance(Duration.ofHours(7));
        long fresh = readId(postAs(user, "/api/workout-logs", "{\"exercise_id\":" + exercise + "}")
                .andExpect(status().isCreated()).andExpect(jsonPath("$.resumed").value(false)), "$.log_id");
        assertThat(fresh).isNotEqualTo(old);
        getAs(user, "/api/workout-logs/" + old).andExpect(jsonPath("$.status").value("aborted"));
        advance(Duration.ofHours(7));
        assertThat(workoutService.abortStale()).isEqualTo(1);
        getAs(user, "/api/workout-logs/" + fresh).andExpect(jsonPath("$.status").value("aborted"));
    }

    @Test
    void logsAreOwnedByTheirUser() throws Exception {
        TestUser user = newUser(true);
        long log = start(user, firstExerciseId(user, "chest"), null);
        TestUser other = newUser(true);
        getAs(other, "/api/workout-logs/" + log).andExpect(status().isNotFound());
        deleteAs(other, "/api/workout-logs/" + log).andExpect(status().isNotFound());
        patchAs(other, "/api/workout-logs/" + log + "/complete", "{}").andExpect(status().isNotFound());
        deleteAs(user, "/api/workout-logs/" + log).andExpect(status().isNoContent());
    }
}
