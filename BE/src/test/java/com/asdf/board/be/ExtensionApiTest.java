package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.support.ApiTestBase;
import com.asdf.board.be.user.entity.User;
import com.jayway.jsonpath.JsonPath;
import java.time.Duration;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ExtensionApiTest extends ApiTestBase {

    private TestUser admin() throws Exception {
        TestUser user = newUser(true);
        User entity = userRepository.findById(user.id()).orElseThrow();
        entity.setRole(User.Role.admin);
        userRepository.saveAndFlush(entity);
        return user;
    }

    private long partner(TestUser admin) throws Exception {
        return readId(postAs(admin, "/api/admin/partners",
                "{\"name\":\"파트너\",\"contract_start\":\"2026-01-01\",\"contract_end\":\"2027-12-31\"}")
                .andExpect(status().isCreated()), "$.partner_id");
    }

    private long coupon(TestUser admin, long partner) throws Exception {
        return readId(postAs(admin, "/api/admin/coupons",
                "{\"partner_id\":%d,\"title\":\"10%% 할인\",\"discount_desc\":\"전 상품 10%%\",\"valid_days\":30}".formatted(partner))
                .andExpect(status().isCreated()), "$.coupon_id");
    }

    private void workout(TestUser user, long exercise) throws Exception {
        long log = readId(postAs(user, "/api/workout-logs", "{\"exercise_id\":" + exercise + "}")
                .andExpect(status().is2xxSuccessful()), "$.log_id");
        postAs(user, "/api/workout-logs/" + log + "/sets",
                "{\"client_set_id\":\"%s\",\"set_no\":1,\"weight_kg\":20,\"reps\":10}".formatted(UUID.randomUUID()))
                .andExpect(status().isCreated());
        advance(Duration.ofMinutes(3));
        patchAs(user, "/api/workout-logs/" + log + "/complete", "{}").andExpect(status().isOk());
    }

    @Test
    void adminEndpointsRequireAdminRole() throws Exception {
        TestUser user = newUser(true);
        getAs(user, "/api/admin/users").andExpect(status().isForbidden()).andExpect(jsonPath("$.code").value("FORBIDDEN"));
        postAs(user, "/api/admin/partners", "{}").andExpect(status().isForbidden());
        getAs(null, "/api/admin/users").andExpect(status().isUnauthorized());
        TestUser admin = admin();
        getAs(admin, "/api/admin/users").andExpect(status().isOk()).andExpect(jsonPath("$.total").isNumber());
        getAs(admin, "/api/admin/users/" + user.id()).andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value(user.email())).andExpect(jsonPath("$.role").value("user"))
                .andExpect(jsonPath("$.onboarding_completed").value(true)).andExpect(jsonPath("$.deleted_at").doesNotExist());
        getAs(admin, "/api/admin/users/999999").andExpect(status().isNotFound());
        getAs(admin, "/api/admin/users?page_size=51").andExpect(status().isBadRequest());
    }

    @Test
    void partnersProductsAreManagedByAdminAndShownInWindow() throws Exception {
        TestUser admin = admin();
        TestUser user = newUser(true);
        postAs(admin, "/api/admin/partners", "{\"name\":\"\",\"contract_start\":\"2026-01-01\",\"contract_end\":\"2026-12-31\"}")
                .andExpect(status().isBadRequest());
        postAs(admin, "/api/admin/partners", "{\"name\":\"x\",\"contract_start\":\"2026-12-31\",\"contract_end\":\"2026-01-01\"}")
                .andExpect(status().isBadRequest());
        long partner = partner(admin);
        patchAs(admin, "/api/admin/partners/" + partner, "{\"name\":\"새이름\"}").andExpect(jsonPath("$.name").value("새이름"));
        patchAs(admin, "/api/admin/partners/999999", "{\"name\":\"x\"}").andExpect(status().isNotFound());
        getAs(admin, "/api/admin/partners").andExpect(status().isOk());

        LocalDate today = LocalDate.now(clock);
        String body = """
                {"partner_id":%d,"category":"food","name":"닭가슴살 도시락","price":5900,
                 "nutrition":{"kcal":320,"carb_g":30,"protein_g":35,"fat_g":6},
                 "link_url":"https://shop.example.com/p/1","display_from":"%s","display_to":"%s"}
                """;
        long visible = readId(postAs(admin, "/api/admin/partner-products", body.formatted(partner, today, today.plusDays(10)))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.is_ad_labeled").value(true))
                .andExpect(jsonPath("$.partner_name").value("새이름")).andExpect(jsonPath("$.nutrition.protein_g").value(35)),
                "$.product_id");
        long hidden = readId(postAs(admin, "/api/admin/partner-products", body.formatted(partner, today.plusDays(5), today.plusDays(9)))
                .andExpect(status().isCreated()), "$.product_id");
        postAs(admin, "/api/admin/partner-products", body.formatted(partner, today.plusDays(9), today.plusDays(5)))
                .andExpect(status().isBadRequest());
        postAs(admin, "/api/admin/partner-products", body.replace("https://shop.example.com/p/1", "not a url").formatted(partner, today, today))
                .andExpect(status().isBadRequest());
        postAs(admin, "/api/admin/partner-products", body.formatted(999999, today, today)).andExpect(status().isNotFound());

        List<Integer> ids = JsonPath.read(getAs(user, "/api/partner-products").andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(), "$.items[*].product_id");
        assertThat(ids).contains((int) visible).doesNotContain((int) hidden);
        getAs(user, "/api/partner-products?category=supplement").andExpect(jsonPath("$.items").isEmpty());
        getAs(user, "/api/partner-products/" + visible).andExpect(status().isOk()).andExpect(jsonPath("$.price").value(5900));
        getAs(user, "/api/partner-products/" + hidden).andExpect(status().isNotFound());

        patchAs(admin, "/api/admin/partner-products/" + hidden,
                "{\"display_from\":\"%s\",\"is_ad_labeled\":false,\"nutrition\":{\"kcal\":null,\"carb_g\":null,\"protein_g\":null,\"fat_g\":null}}"
                        .formatted(today)).andExpect(status().isOk()).andExpect(jsonPath("$.is_ad_labeled").value(false))
                .andExpect(jsonPath("$.nutrition").doesNotExist());
        getAs(user, "/api/partner-products/" + hidden).andExpect(status().isOk());
        patchAs(admin, "/api/admin/partner-products/999999", "{\"name\":\"x\"}").andExpect(status().isNotFound());
        getAs(newUser(false), "/api/partner-products").andExpect(status().isForbidden());
    }

    @Test
    void missionCompletionIssuesCouponOnce() throws Exception {
        TestUser admin = admin();
        TestUser user = newUser(true);
        getAs(user, "/api/missions/current").andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("NO_ACTIVE_MISSION"));
        long coupon = coupon(admin, partner(admin));
        postAs(admin, "/api/admin/missions", "{\"title\":\"m\",\"condition_json\":{\"type\":\"bogus\",\"count\":2},\"period_days\":7}")
                .andExpect(status().isBadRequest());
        long mission = readId(postAs(admin, "/api/admin/missions",
                "{\"title\":\"이번 주 2일 운동\",\"condition_json\":{\"type\":\"workout_days\",\"count\":2},\"period_days\":7,\"coupon_id\":%d}"
                        .formatted(coupon)).andExpect(status().isCreated()).andExpect(jsonPath("$.is_active").value(true))
                .andExpect(jsonPath("$.condition_json.count").value(2)), "$.mission_id");

        getAs(user, "/api/missions/current").andExpect(status().isOk()).andExpect(jsonPath("$.mission_id").value(mission))
                .andExpect(jsonPath("$.target_count").value(2)).andExpect(jsonPath("$.reward_title").value("10% 할인"))
                .andExpect(jsonPath("$.period_days").value(7));
        getAs(user, "/api/missions/" + mission + "/progress").andExpect(jsonPath("$.current").value(0))
                .andExpect(jsonPath("$.percent").value(0)).andExpect(jsonPath("$.completed").value(false));
        getAs(user, "/api/user-coupons").andExpect(jsonPath("$.total").value(0));

        long exercise = firstExerciseId(user, "chest");
        workout(user, exercise);
        getAs(user, "/api/missions/" + mission + "/progress").andExpect(jsonPath("$.current").value(1))
                .andExpect(jsonPath("$.percent").value(50));
        workout(user, exercise);
        getAs(user, "/api/missions/" + mission + "/progress").andExpect(jsonPath("$.current").value(1));
        advance(Duration.ofDays(1));
        workout(user, exercise);
        getAs(user, "/api/missions/" + mission + "/progress").andExpect(jsonPath("$.completed").value(true))
                .andExpect(jsonPath("$.percent").value(100));
        getAs(user, "/api/missions/" + mission + "/progress").andExpect(jsonPath("$.completed").value(true));

        String coupons = getAs(user, "/api/user-coupons").andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.items[0].status").value("available")).andExpect(jsonPath("$.items[0].discount_desc").value("전 상품 10%"))
                .andReturn().getResponse().getContentAsString();
        long userCoupon = ((Number) JsonPath.read(coupons, "$.items[0].user_coupon_id")).longValue();
        getAs(user, "/api/user-coupons/" + userCoupon).andExpect(status().isOk()).andExpect(jsonPath("$.partner_name").value("파트너"));
        getAs(newUser(true), "/api/user-coupons/" + userCoupon).andExpect(status().isNotFound());
        getAs(user, "/api/user-coupons?status=used").andExpect(jsonPath("$.total").value(0));
        advance(Duration.ofDays(40));
        getAs(user, "/api/user-coupons?status=expired").andExpect(jsonPath("$.total").value(1));
        getAs(user, "/api/user-coupons?status=available").andExpect(jsonPath("$.total").value(0));

        getAs(user, "/api/missions/999999/progress").andExpect(status().isNotFound());
        patchAs(admin, "/api/admin/missions/" + mission, "{\"is_active\":false}").andExpect(jsonPath("$.is_active").value(false));
        patchAs(admin, "/api/admin/missions/999999", "{\"title\":\"x\"}").andExpect(status().isNotFound());
        patchAs(admin, "/api/admin/coupons/" + coupon, "{\"valid_days\":10}").andExpect(jsonPath("$.valid_days").value(10));
        postAs(admin, "/api/admin/coupons", "{\"partner_id\":999999,\"title\":\"x\",\"discount_desc\":\"y\",\"valid_days\":1}")
                .andExpect(status().isNotFound());
    }

    @Test
    void notificationSettingsAndDeviceToken() throws Exception {
        TestUser user = newUser(true);
        String settings = getAs(user, "/api/notification-settings").andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(3)).andReturn().getResponse().getContentAsString();
        assertThat((List<String>) JsonPath.read(settings, "$.items[*].type")).containsExactly("workout", "diet", "streak_risk");
        assertThat((Object) JsonPath.read(settings, "$.items[2].time")).isNull();
        patchAs(user, "/api/notification-settings/workout", "{\"enabled\":false,\"time\":\"07:30\"}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.enabled").value(false)).andExpect(jsonPath("$.time").value("07:30"));
        getAs(user, "/api/notification-settings").andExpect(jsonPath("$.items[?(@.type=='workout')].time").value("07:30"));
        patchAs(user, "/api/notification-settings/workout", "{}").andExpect(status().isBadRequest());
        patchAs(user, "/api/notification-settings/workout", "{\"time\":\"25:00\"}").andExpect(status().isBadRequest());
        patchAs(user, "/api/notification-settings/streak_risk", "{\"time\":\"09:00\"}").andExpect(status().isBadRequest());
        patchAs(user, "/api/notification-settings/streak_risk", "{\"enabled\":false}").andExpect(status().isOk());
        patchAs(user, "/api/notification-settings/bogus", "{\"enabled\":true}").andExpect(status().isBadRequest());

        putAs(user, "/api/users/me/device-token", "{\"fcm_token\":\"" + "t".repeat(300) + "\",\"platform\":\"ios\"}")
                .andExpect(status().isNoContent());
        putAs(user, "/api/users/me/device-token", "{\"fcm_token\":\"" + "u".repeat(4096) + "\",\"platform\":\"ios\"}")
                .andExpect(status().isNoContent());
        TestUser other = newUser(true);
        putAs(other, "/api/users/me/device-token", "{\"fcm_token\":\"" + "u".repeat(4096) + "\",\"platform\":\"ios\"}")
                .andExpect(status().isNoContent());
        putAs(user, "/api/users/me/device-token", "{\"fcm_token\":\"abc\",\"platform\":\"android\"}").andExpect(status().isNoContent());
        putAs(user, "/api/users/me/device-token", "{\"fcm_token\":\"\",\"platform\":\"ios\"}").andExpect(status().isBadRequest());
        putAs(user, "/api/users/me/device-token", "{\"fcm_token\":\"a\",\"platform\":\"web\"}").andExpect(status().isBadRequest());
        putAs(newUser(false), "/api/users/me/device-token", "{\"fcm_token\":\"a\",\"platform\":\"ios\"}").andExpect(status().isForbidden());
        deleteAs(other, "/api/users/me").andExpect(status().isNoContent());
    }

    @Test
    void adminManagesExercisesAndCorrections() throws Exception {
        TestUser admin = admin();
        TestUser user = newUser(true);
        String create = """
                {"name":"새 운동","target_part":"chest","difficulty":2,"equipment":"dumbbell","min_sets":2,"max_sets":4,
                 "description":"설명","media_url":"https://video.example.com/a.mp4"}
                """;
        long id = readId(postAs(admin, "/api/admin/exercises", create).andExpect(status().isCreated())
                .andExpect(jsonPath("$.min_sets").value(2)).andExpect(jsonPath("$.description").value("설명")), "$.exercise_id");
        postAs(admin, "/api/admin/exercises", create).andExpect(status().isBadRequest());
        patchAs(admin, "/api/admin/exercises/" + id, "{\"name\":\"푸시업\"}").andExpect(status().isBadRequest());
        postAs(admin, "/api/admin/exercises", create.replace("\"min_sets\":2,\"max_sets\":4", "\"min_sets\":5,\"max_sets\":4"))
                .andExpect(status().isBadRequest());
        getAs(user, "/api/exercises/" + id).andExpect(status().isOk()).andExpect(jsonPath("$.max_sets").value(4));
        patchAs(admin, "/api/admin/exercises/" + id, "{\"name\":\"이름변경\",\"max_sets\":6}").andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("이름변경")).andExpect(jsonPath("$.max_sets").value(6));
        patchAs(admin, "/api/admin/exercises/" + id, "{\"min_sets\":9}").andExpect(status().isBadRequest());
        patchAs(admin, "/api/admin/exercises/999999", "{\"name\":\"x\"}").andExpect(status().isNotFound());

        long corr = readId(postAs(admin, "/api/admin/correction-exercises",
                "{\"target_issue\":\"neck_forward\",\"name\":\"턱 당기기\",\"method\":\"턱을 당깁니다\",\"duration_or_reps\":\"10회\"}")
                .andExpect(status().isCreated()).andExpect(jsonPath("$.method").value("턱을 당깁니다")), "$.correction_id");
        patchAs(admin, "/api/admin/correction-exercises/" + corr, "{\"duration_or_reps\":\"15회\"}")
                .andExpect(jsonPath("$.duration_or_reps").value("15회"));
        getAs(user, "/api/correction-exercises/" + corr).andExpect(status().isOk());
        patchAs(admin, "/api/admin/correction-exercises/999999", "{\"name\":\"x\"}").andExpect(status().isNotFound());
        postAs(admin, "/api/admin/correction-exercises", "{\"target_issue\":\"bogus\",\"name\":\"x\",\"method\":\"y\",\"duration_or_reps\":\"z\"}")
                .andExpect(status().isBadRequest());
    }

    @Test
    void adminHandlesReports() throws Exception {
        TestUser admin = admin();
        TestUser author = newUser(true);
        long post = readId(mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart("/api/posts")
                .param("category", "info").param("title", "t").param("content", "c")
                .header("Authorization", "Bearer " + author.token())).andExpect(status().isCreated()), "$.post_id");
        long first = 0;
        for (int i = 0; i < 3; i++) {
            long rid = readId(postAs(newUser(true), "/api/reports",
                    "{\"target_type\":\"post\",\"target_id\":%d,\"reason\":\"spam\"}".formatted(post)).andExpect(status().isCreated()), "$.report_id");
            first = first == 0 ? rid : first;
        }
        TestUser reader = newUser(true);
        getAs(reader, "/api/posts/" + post).andExpect(status().isNotFound());
        getAs(admin, "/api/admin/reports?status=pending").andExpect(status().isOk()).andExpect(jsonPath("$.total").value(3))
                .andExpect(jsonPath("$.items[0].reporter_id").isNumber());
        patchAs(admin, "/api/admin/reports/" + first, "{\"status\":\"pending\"}").andExpect(status().isBadRequest());
        patchAs(admin, "/api/admin/reports/" + first, "{\"status\":\"rejected\"}").andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("rejected"));
        getAs(reader, "/api/posts/" + post).andExpect(status().isOk());
        patchAs(admin, "/api/admin/reports/" + first, "{\"status\":\"resolved\"}").andExpect(jsonPath("$.status").value("resolved"));
        getAs(reader, "/api/posts/" + post).andExpect(status().isNotFound());
        patchAs(admin, "/api/admin/reports/999999", "{\"status\":\"resolved\"}").andExpect(status().isNotFound());
        getAs(admin, "/api/admin/reports?status=bogus").andExpect(status().isBadRequest());
    }
}
