package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.support.ApiTestBase;
import com.jayway.jsonpath.JsonPath;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class ExerciseRoutineApiTest extends ApiTestBase {

    @Test
    void exercisesRequireOnboardingAndListByName() throws Exception {
        getAs(newUser(false), "/api/exercises").andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ONBOARDING_REQUIRED"));
        TestUser user = newUser(true);
        getAs(user, "/api/exercises?page_size=50").andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(24))
                .andExpect(jsonPath("$.items[0].min_sets").isNumber())
                .andExpect(jsonPath("$.items[0].max_sets").isNumber())
                .andExpect(jsonPath("$.items[0].target_part").isNotEmpty());
        List<String> names = JsonPath.read(getAs(user, "/api/exercises?page_size=50").andReturn()
                .getResponse().getContentAsString(), "$.items[*].name");
        assertThat(names).isSortedAccordingTo(java.util.Comparator.naturalOrder());
    }

    @Test
    void exerciseFilters() throws Exception {
        TestUser user = newUser(true);
        getAs(user, "/api/exercises?target_part=chest").andExpect(jsonPath("$.total").value(4))
                .andExpect(jsonPath("$.items[0].target_part").value("chest"));
        getAs(user, "/api/exercises?equipment=barbell").andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].equipment").value("barbell"));
        getAs(user, "/api/exercises?difficulty=1").andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].difficulty").value(1));
        getAs(user, "/api/exercises?q=벤치 프레스").andExpect(jsonPath("$.total").value(org.hamcrest.Matchers.greaterThanOrEqualTo(2)));
        getAs(user, "/api/exercises?q=없는운동이름").andExpect(jsonPath("$.total").value(0));
        getAs(user, "/api/exercises?target_part=wrong").andExpect(status().isBadRequest());
        getAs(user, "/api/exercises?difficulty=6").andExpect(status().isBadRequest());
        getAs(user, "/api/exercises?page_size=51").andExpect(status().isBadRequest());
        getAs(user, "/api/exercises?page=2&page_size=10").andExpect(jsonPath("$.items.length()").value(10));
    }

    @Test
    void exerciseDetailAndSetsFollowExperience() throws Exception {
        TestUser beginner = newUser(false);
        postAs(beginner, "/api/users/me/profile", PROFILE_JSON.replace("under1y", "under3m")).andExpect(status().isCreated());
        TestUser expert = newUser(false);
        postAs(expert, "/api/users/me/profile", PROFILE_JSON.replace("under1y", "over1y")).andExpect(status().isCreated());
        long id = firstExerciseId(beginner, "chest");
        int beginnerMax = read(getAs(beginner, "/api/exercises/" + id).andExpect(status().isOk()), "$.max_sets");
        int expertMax = read(getAs(expert, "/api/exercises/" + id).andExpect(status().isOk()), "$.max_sets");
        assertThat(expertMax).isGreaterThanOrEqualTo(beginnerMax);
        getAs(beginner, "/api/exercises/999999").andExpect(status().isNotFound());
    }

    @Test
    void routineCreationNeedsDoneAnalysis() throws Exception {
        TestUser user = newUser(true);
        postAs(user, "/api/routines", "{}").andExpect(status().isBadRequest());
        postAs(user, "/api/routines", "{\"analysis_id\":999999999}").andExpect(status().isNotFound());
        long photo = uploadPhoto(user, "current", "front", 5);
        long pending = readId(postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}")
                .andExpect(status().isAccepted()), "$.analysis_id");
        postAs(user, "/api/routines", "{\"analysis_id\":" + pending + "}").andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ANALYSIS_NOT_READY"));
        asyncRunner.drain();
        TestUser other = newUser(true);
        postAs(other, "/api/routines", "{\"analysis_id\":" + pending + "}").andExpect(status().isNotFound());
        postAs(newUser(false), "/api/routines", "{\"analysis_id\":1}").andExpect(status().isForbidden());
    }

    @Test
    void createsRoutinesOnTrainingDaysWithRuleBasedItems() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, true);
        String body = postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.analysis_id").value(analysis))
                .andExpect(jsonPath("$.routines.length()").value(4))
                .andReturn().getResponse().getContentAsString();
        List<String> dates = JsonPath.read(body, "$.routines[*].scheduled_date");
        assertThat(dates).doesNotHaveDuplicates();
        LocalDate today = LocalDate.now();
        for (String d : dates) {
            LocalDate date = LocalDate.parse(d);
            assertThat(date).isBetween(today, today.plusDays(6));
        }
        assertThat(dates.get(0)).isEqualTo(today.toString());
        List<String> parts = JsonPath.read(body, "$.routines[*].target_part");
        List<String> priority = JsonPath.read(getAs(user, "/api/body-analyses/" + analysis).andReturn()
                .getResponse().getContentAsString(), "$.goal_comparison.priority_parts[*].part");
        assertThat(priority).contains(parts.get(0));
        assertThat((String) JsonPath.read(body, "$.routines[0].title")).endsWith("집중 루틴");
        int count = JsonPath.read(body, "$.routines[0].items.length()");
        assertThat(count).isBetween(1, 4);
        for (int i = 0; i < count; i++) {
            String item = "$.routines[0].items[" + i + "]";
            assertThat((Integer) JsonPath.read(body, item + ".order_no")).isEqualTo(i + 1);
            assertThat((String) JsonPath.read(body, item + ".exercise.target_part")).isEqualTo(parts.get(0));
            int sets = JsonPath.read(body, item + ".target_sets");
            int min = JsonPath.read(body, item + ".exercise.min_sets");
            int max = JsonPath.read(body, item + ".exercise.max_sets");
            assertThat(sets).isBetween(min, max);
            assertThat((Integer) JsonPath.read(body, item + ".target_reps")).isPositive();
            assertThat((Integer) JsonPath.read(body, item + ".rest_sec")).isPositive();
            assertThat((Boolean) JsonPath.read(body, item + ".done")).isFalse();
        }
        assertThat((Integer) JsonPath.read(body, "$.routines[0].estimated_minutes")).isPositive();
    }

    @Test
    void recreatingReplacesPlannedRoutines() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        String first = postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        String second = postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}")
                .andExpect(status().isCreated()).andExpect(jsonPath("$.routines.length()").value(4))
                .andReturn().getResponse().getContentAsString();
        assertThat((Integer) JsonPath.read(first, "$.routines[0].routine_id"))
                .isNotEqualTo(JsonPath.read(second, "$.routines[0].routine_id"));
        getAs(user, "/api/routines/" + ((Number) JsonPath.read(first, "$.routines[0].routine_id")).longValue())
                .andExpect(status().isNotFound());
    }

    @Test
    void todayWeeklyAndDetail() throws Exception {
        TestUser user = newUser(true);
        getAs(user, "/api/routines/today").andExpect(status().isOk())
                .andExpect(jsonPath("$.is_rest_day").value(true)).andExpect(jsonPath("$.routine").doesNotExist());
        long analysis = doneAnalysis(user, false);
        long routineId = ((Number) JsonPath.read(postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString(),
                "$.routines[0].routine_id")).longValue();
        getAs(user, "/api/routines/today").andExpect(jsonPath("$.is_rest_day").value(false))
                .andExpect(jsonPath("$.routine.routine_id").value(routineId))
                .andExpect(jsonPath("$.date").value(LocalDate.now().toString()));
        getAs(user, "/api/routines/today?date=" + LocalDate.now().plusDays(6)).andExpect(status().isOk());
        getAs(user, "/api/routines/today?date=bad").andExpect(status().isBadRequest());
        getAs(user, "/api/routines/" + routineId).andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("planned"))
                .andExpect(jsonPath("$.analysis_id").value(analysis));
        getAs(newUser(true), "/api/routines/" + routineId).andExpect(status().isNotFound());

        String week = getAs(user, "/api/routines/weekly").andExpect(status().isOk())
                .andExpect(jsonPath("$.days.length()").value(7)).andReturn().getResponse().getContentAsString();
        LocalDate monday = LocalDate.parse(JsonPath.read(week, "$.week_start"));
        assertThat(monday.getDayOfWeek()).isEqualTo(java.time.DayOfWeek.MONDAY);
        assertThat((String) JsonPath.read(week, "$.days[0].date")).isEqualTo(monday.toString());
        getAs(user, "/api/routines/weekly?week_start=" + monday.plusDays(1)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        getAs(user, "/api/routines/weekly?week_start=" + monday.plusWeeks(1)).andExpect(status().isOk())
                .andExpect(jsonPath("$.days.length()").value(7));
        List<Boolean> rest = JsonPath.read(week, "$.days[*].is_rest_day");
        assertThat(rest).contains(true);
    }
}
