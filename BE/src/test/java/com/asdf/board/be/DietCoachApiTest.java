package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.Duration;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class DietCoachApiTest extends com.asdf.board.be.support.ApiTestBase {

    private String createDiet(TestUser user, long analysis) throws Exception {
        return postAs(user, "/api/diet-plans", "{\"analysis_id\":" + analysis + "}")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
    }

    private static void jsonPathNotNull(String body) {
        assertThat((Object) JsonPath.read(body, "$.suggestion")).as("제안이 나와야 합니다: " + body).isNotNull();
    }

    @Test
    void createsSevenDayDietWithCalorieTarget() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        String body = createDiet(user, analysis);
        LocalDate today = LocalDate.now(clock);

        assertThat((Integer) JsonPath.read(body, "$.plans.length()")).isEqualTo(7);
        assertThat((String) JsonPath.read(body, "$.plans[0].date")).isEqualTo(today.toString());
        assertThat((String) JsonPath.read(body, "$.plans[6].date")).isEqualTo(today.plusDays(6).toString());
        int kcal = JsonPath.read(body, "$.plans[0].target_kcal");
        assertThat(kcal).isBetween(2400, 3400);
        List<String> types = JsonPath.read(body, "$.plans[0].meals[*].meal_type");
        assertThat(types).containsExactly("breakfast", "lunch", "dinner", "snack");
        int mealTotal = 0;
        for (int i = 0; i < 4; i++) {
            int total = JsonPath.read(body, "$.plans[0].meals[" + i + "].total_kcal");
            List<Integer> items = JsonPath.read(body, "$.plans[0].meals[" + i + "].items[*].kcal");
            assertThat(items.stream().mapToInt(Integer::intValue).sum()).isEqualTo(total);
            mealTotal += total;
        }
        assertThat(mealTotal).isBetween((int) (kcal * 0.8), (int) (kcal * 1.2));

        long planId = ((Number) JsonPath.read(body, "$.plans[2].plan_id")).longValue();
        getAs(user, "/api/diet-plans/" + planId).andExpect(status().isOk()).andExpect(jsonPath("$.plan_id").value(planId))
                .andExpect(jsonPath("$.meals.length()").value(4));
        getAs(user, "/api/diet-plans").andExpect(status().isOk()).andExpect(jsonPath("$.date").value(today.toString()));
        getAs(user, "/api/diet-plans?plan_date=" + today.plusDays(3)).andExpect(status().isOk());
        getAs(user, "/api/diet-plans?plan_date=" + today.plusDays(30))
                .andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("DIET_NOT_FOUND"));
        getAs(newUser(true), "/api/diet-plans/" + planId).andExpect(status().isNotFound());
    }

    @Test
    void regenerationReplacesAndAllergiesAreExcluded() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        String first = createDiet(user, analysis);
        postAs(user, "/api/users/me/allergies", "{\"item\":\"계란\"}").andExpect(status().isCreated());
        postAs(user, "/api/users/me/allergies", "{\"item\":\"우유\"}").andExpect(status().isCreated());
        postAs(user, "/api/users/me/allergies", "{\"item\":\"닭\"}").andExpect(status().isCreated());
        String second = createDiet(user, analysis);

        List<String> foods = JsonPath.read(second, "$.plans[*].meals[*].items[*].food_name");
        assertThat(foods).isNotEmpty();
        assertThat(foods).noneMatch(f -> f.contains("달걀") || f.contains("계란") || f.contains("요거트")
                || f.contains("쉐이크") || f.contains("닭"));
        long oldId = ((Number) JsonPath.read(first, "$.plans[0].plan_id")).longValue();
        getAs(user, "/api/diet-plans/" + oldId).andExpect(status().isNotFound());
        assertThat((Integer) JsonPath.read(second, "$.plans.length()")).isEqualTo(7);
    }

    @Test
    void dietCreateValidatesAnalysis() throws Exception {
        TestUser user = newUser(true);
        postAs(user, "/api/diet-plans", "{}").andExpect(status().isBadRequest());
        postAs(user, "/api/diet-plans", "{\"analysis_id\":999999}").andExpect(status().isNotFound());
        long photo = uploadPhoto(user, "current", "front", 7);
        long pending = readId(postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}")
                .andExpect(status().isAccepted()), "$.analysis_id");
        postAs(user, "/api/diet-plans", "{\"analysis_id\":" + pending + "}")
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("ANALYSIS_NOT_READY"));
        postAs(newUser(false), "/api/diet-plans", "{\"analysis_id\":1}").andExpect(status().isForbidden());
        getAs(newUser(false), "/api/diet-plans").andExpect(status().isForbidden());
    }

    @Test
    void coachAnswersAndCountsQuota() throws Exception {
        TestUser user = newUser(true);
        getAs(user, "/api/ai/usage").andExpect(status().isOk()).andExpect(jsonPath("$.used").value(0))
                .andExpect(jsonPath("$.limit").value(30)).andExpect(jsonPath("$.remaining").value(30));
        postAs(user, "/api/ai/chat", "{\"content\":\"요즘 운동 어때?\"}").andExpect(status().isOk())
                .andExpect(jsonPath("$.user_message.role").value("user"))
                .andExpect(jsonPath("$.user_message.content").value("요즘 운동 어때?"))
                .andExpect(jsonPath("$.reply.role").value("assistant"))
                .andExpect(jsonPath("$.reply.content").isNotEmpty())
                .andExpect(jsonPath("$.suggestion").doesNotExist())
                .andExpect(jsonPath("$.remaining_today").value(29));
        postAs(user, "/api/ai/chat", "{\"content\":\"허리가 아파요\"}").andExpect(status().isOk())
                .andExpect(jsonPath("$.reply.content").value(org.hamcrest.Matchers.containsString("전문의")));

        getAs(user, "/api/ai/chat").andExpect(status().isOk()).andExpect(jsonPath("$.total").value(4))
                .andExpect(jsonPath("$.items[0].role").value("assistant"))
                .andExpect(jsonPath("$.items[3].content").value("요즘 운동 어때?"));
        getAs(user, "/api/ai/chat?page=2&page_size=3").andExpect(jsonPath("$.items.length()").value(1));
        getAs(user, "/api/ai/usage").andExpect(jsonPath("$.used").value(2)).andExpect(jsonPath("$.remaining").value(28));

        postAs(user, "/api/ai/chat", "{\"content\":\"\"}").andExpect(status().isBadRequest());
        postAs(user, "/api/ai/chat", "{\"content\":\"" + "가".repeat(501) + "\"}").andExpect(status().isBadRequest());
        postAs(newUser(false), "/api/ai/chat", "{\"content\":\"안녕\"}").andExpect(status().isForbidden());

        for (int i = 0; i < 28; i++) {
            postAs(user, "/api/ai/chat", "{\"content\":\"질문" + i + "\"}").andExpect(status().isOk());
        }
        postAs(user, "/api/ai/chat", "{\"content\":\"하나 더\"}")
                .andExpect(status().isTooManyRequests()).andExpect(jsonPath("$.code").value("AI_QUOTA_EXCEEDED"));
        advance(Duration.ofDays(1));
        postAs(user, "/api/ai/chat", "{\"content\":\"내일\"}").andExpect(status().isOk());
    }

    @Test
    void coachIsBlockedWhenAiConsentIsWithdrawnButHistoryStaysReadable() throws Exception {
        TestUser user = newUser(true);
        postAs(user, "/api/ai/chat", "{\"content\":\"안녕\"}").andExpect(status().isOk());
        patchAs(user, "/api/users/me", "{\"ai_processing_agreed\":false}").andExpect(status().isOk());
        postAs(user, "/api/ai/chat", "{\"content\":\"또\"}")
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("CONSENT_REQUIRED"));
        getAs(user, "/api/ai/chat").andExpect(status().isOk()).andExpect(jsonPath("$.total").value(2));
        getAs(user, "/api/ai/usage").andExpect(status().isOk()).andExpect(jsonPath("$.used").value(1));
        patchAs(user, "/api/users/me", "{\"ai_processing_agreed\":true}").andExpect(status().isOk());
        postAs(user, "/api/ai/chat", "{\"content\":\"다시\"}").andExpect(status().isOk());
    }

    @Test
    void aiFailureDoesNotStoreQuestionOrCountQuota() throws Exception {
        TestUser user = newUser(true);
        coachAi.setDown(true);
        postAs(user, "/api/ai/chat", "{\"content\":\"안녕\"}")
                .andExpect(status().isBadGateway()).andExpect(jsonPath("$.code").value("AI_UNAVAILABLE"));
        getAs(user, "/api/ai/usage").andExpect(jsonPath("$.used").value(0));
        getAs(user, "/api/ai/chat").andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void suggestionChangesRoutineOnlyAfterConfirm() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        String routines = postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long routineId = ((Number) JsonPath.read(routines, "$.routines[0].routine_id")).longValue();
        String before = getAs(user, "/api/routines/" + routineId).andReturn().getResponse().getContentAsString();
        String ask = postAs(user, "/api/ai/chat", "{\"content\":\"이 루틴 너무 어려워요 쉬운 걸로 바꿔줘\"}")
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        jsonPathNotNull(ask);
        long suggestionId = ((Number) JsonPath.read(ask, "$.suggestion.suggestion_id")).longValue();
        assertThat((String) JsonPath.read(ask, "$.suggestion.status")).isEqualTo("pending");
        assertThat((String) JsonPath.read(ask, "$.suggestion.changes[0].action")).isEqualTo("replace");
        long itemId = ((Number) JsonPath.read(ask, "$.suggestion.changes[0].routine_item_id")).longValue();
        List<Integer> currentList = JsonPath.read(before, "$.items[?(@.item_id==" + itemId + ")].exercise.difficulty");
        int current = currentList.get(0);
        int proposed = JsonPath.read(ask, "$.suggestion.changes[0].exercise.difficulty");
        assertThat(proposed).as("쉽게 해 달라는 요청에 더 어려운 종목을 제안하면 안 됩니다").isLessThanOrEqualTo(current);
        assertThat((String) JsonPath.read(ask, "$.reply.suggestion.status")).isEqualTo("pending");

        assertThat(getAs(user, "/api/routines/" + routineId).andReturn().getResponse().getContentAsString()).isEqualTo(before);
        postAs(newUser(true), "/api/ai/routine-suggestions/" + suggestionId + "/confirm", "{\"confirmed\":true}")
                .andExpect(status().isNotFound());
        postAs(user, "/api/ai/routine-suggestions/" + suggestionId + "/confirm", "{}").andExpect(status().isBadRequest());
        postAs(user, "/api/ai/routine-suggestions/" + suggestionId + "/confirm", "{\"confirmed\":true}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("applied"))
                .andExpect(jsonPath("$.routine.routine_id").isNotEmpty());
        postAs(user, "/api/ai/routine-suggestions/" + suggestionId + "/confirm", "{\"confirmed\":true}")
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("SUGGESTION_ALREADY_HANDLED"));
    }

    @Test
    void suggestionCanBeDismissedAndExpires() throws Exception {
        TestUser user = newUser(true);
        long analysis = doneAnalysis(user, false);
        postAs(user, "/api/routines", "{\"analysis_id\":" + analysis + "}").andExpect(status().isCreated());
        String first = postAs(user, "/api/ai/chat", "{\"content\":\"하나 빼줘\"}").andReturn().getResponse().getContentAsString();
        jsonPathNotNull(first);
        long id = ((Number) JsonPath.read(first, "$.suggestion.suggestion_id")).longValue();
        postAs(user, "/api/ai/routine-suggestions/" + id + "/confirm", "{\"confirmed\":false}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("dismissed"))
                .andExpect(jsonPath("$.routine").doesNotExist());
        postAs(user, "/api/ai/routine-suggestions/" + id + "/confirm", "{\"confirmed\":true}")
                .andExpect(status().isConflict());

        String second = postAs(user, "/api/ai/chat", "{\"content\":\"하나 빼줘\"}").andReturn().getResponse().getContentAsString();
        long other = ((Number) JsonPath.read(second, "$.suggestion.suggestion_id")).longValue();
        advance(Duration.ofHours(25));
        postAs(user, "/api/ai/routine-suggestions/" + other + "/confirm", "{\"confirmed\":true}")
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("SUGGESTION_EXPIRED"));
    }
}
