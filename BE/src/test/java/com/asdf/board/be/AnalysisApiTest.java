package com.asdf.board.be;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.support.ApiTestBase;
import com.asdf.board.be.support.TestImages;
import org.junit.jupiter.api.Test;

class AnalysisApiTest extends ApiTestBase {

    private long front(TestUser user, long seed) throws Exception {
        return uploadPhoto(user, "current", "front", seed);
    }

    private long side(TestUser user, long seed) throws Exception {
        return uploadPhoto(user, "current", "side", seed);
    }

    @Test
    void acceptsRequestThenCompletesWithMeasures() throws Exception {
        TestUser user = newUser(true);
        long photo = front(user, 1);
        long id = readId(postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}")
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.status").value("pending"))
                .andExpect(jsonPath("$.poll_after_ms").value(2000)), "$.analysis_id");
        getAs(user, "/api/body-analyses/" + id).andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("pending"))
                .andExpect(jsonPath("$.measures").doesNotExist())
                .andExpect(jsonPath("$.judgements.length()").value(0))
                .andExpect(jsonPath("$.error_code").doesNotExist());
        asyncRunner.drain();
        getAs(user, "/api/body-analyses/" + id).andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("done"))
                .andExpect(jsonPath("$.source").value("photo"))
                .andExpect(jsonPath("$.photo_id").value(photo))
                .andExpect(jsonPath("$.measures.shoulder_tilt_deg").isNumber())
                .andExpect(jsonPath("$.measures.neck_forward_deg").doesNotExist())
                .andExpect(jsonPath("$.measures.unavailable[0].key").value("neck_forward"))
                .andExpect(jsonPath("$.measures.unavailable[0].reason").value("SIDE_PHOTO_MISSING"))
                .andExpect(jsonPath("$.judgements.length()").value(3))
                .andExpect(jsonPath("$.judgements[2].level").value("unavailable"))
                .andExpect(jsonPath("$.balance_score").doesNotExist())
                .andExpect(jsonPath("$.measurement_version").value("stub-v0"))
                .andExpect(jsonPath("$.goal_comparison").doesNotExist())
                .andExpect(jsonPath("$.completed_at").isNotEmpty());
    }

    @Test
    void sidePhotoAddsNeckAngle() throws Exception {
        TestUser user = newUser(true);
        long id = readId(postAs(user, "/api/body-analyses/photo",
                "{\"photo_id\":%d,\"side_photo_id\":%d}".formatted(front(user, 2), side(user, 3)))
                .andExpect(status().isAccepted()), "$.analysis_id");
        asyncRunner.drain();
        getAs(user, "/api/body-analyses/" + id)
                .andExpect(jsonPath("$.measures.neck_forward_deg").isNumber())
                .andExpect(jsonPath("$.measures.unavailable.length()").value(0))
                .andExpect(jsonPath("$.judgements[2].value").isNumber());
    }

    @Test
    void comparesWithGoalWhenGoalIsReady() throws Exception {
        TestUser user = newUser(true);
        long goal = readId(postAs(user, "/api/goal-bodies", "{\"description\":\"넓은 어깨\"}")
                .andExpect(status().isCreated()), "$.goal_body_id");
        long id = readId(postAs(user, "/api/body-analyses/photo",
                "{\"photo_id\":%d,\"goal_body_id\":%d}".formatted(front(user, 4), goal))
                .andExpect(status().isAccepted()), "$.analysis_id");
        asyncRunner.drain();
        getAs(user, "/api/body-analyses/" + id).andExpect(jsonPath("$.goal_body_id").value(goal))
                .andExpect(jsonPath("$.goal_comparison.priority_parts.length()").value(2))
                .andExpect(jsonPath("$.goal_comparison.priority_parts[0].part").isNotEmpty())
                .andExpect(jsonPath("$.goal_comparison.summary").isNotEmpty())
                .andExpect(jsonPath("$.goal_comparison.detail").isNotEmpty());
    }

    @Test
    void goalMustBeDoneAndOwned() throws Exception {
        TestUser user = newUser(true);
        long goalPhoto = uploadPhoto(user, "goal", "front", 5);
        long goal = readId(postAs(user, "/api/goal-bodies", "{\"photo_id\":" + goalPhoto + "}")
                .andExpect(status().isCreated()), "$.goal_body_id");
        long photo = front(user, 6);
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":%d,\"goal_body_id\":%d}".formatted(photo, goal))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("GOAL_NOT_READY"));
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":%d,\"goal_body_id\":999999999}".formatted(photo))
                .andExpect(status().isNotFound());
    }

    @Test
    void validatesPhotoKindsAndOwnership() throws Exception {
        TestUser user = newUser(true);
        postAs(user, "/api/body-analyses/photo", "{}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        long sidePhoto = side(user, 7);
        long goalPhoto = uploadPhoto(user, "goal", "front", 8);
        long frontPhoto = front(user, 9);
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + sidePhoto + "}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("PHOTO_TYPE_MISMATCH"));
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + goalPhoto + "}").andExpect(status().isBadRequest());
        postAs(user, "/api/body-analyses/photo",
                "{\"photo_id\":%d,\"side_photo_id\":%d}".formatted(frontPhoto, frontPhoto))
                .andExpect(status().isBadRequest());
        TestUser other = newUser(true);
        postAs(other, "/api/body-analyses/photo", "{\"photo_id\":" + frontPhoto + "}").andExpect(status().isNotFound());
        TestUser fresh = newUser(false);
        postAs(fresh, "/api/body-analyses/photo", "{\"photo_id\":1}").andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ONBOARDING_REQUIRED"));
    }

    @Test
    void allowsOnePendingAnalysisAtATime() throws Exception {
        TestUser user = newUser(true);
        long photo = front(user, 10);
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}").andExpect(status().isAccepted());
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}").andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ANALYSIS_IN_PROGRESS"));
        asyncRunner.drain();
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}").andExpect(status().isAccepted());
    }

    @Test
    void limitsThreeAnalysesPerDayAndReportsUsage() throws Exception {
        TestUser user = newUser(true);
        long photo = front(user, 11);
        getAs(user, "/api/body-analyses/usage").andExpect(status().isOk())
                .andExpect(jsonPath("$.used").value(0)).andExpect(jsonPath("$.limit").value(3))
                .andExpect(jsonPath("$.remaining").value(3)).andExpect(jsonPath("$.reset_at").isNotEmpty());
        for (int i = 0; i < 3; i++) {
            postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}").andExpect(status().isAccepted());
            asyncRunner.drain();
        }
        getAs(user, "/api/body-analyses/usage").andExpect(jsonPath("$.used").value(3))
                .andExpect(jsonPath("$.remaining").value(0));
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}").andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("ANALYSIS_QUOTA_EXCEEDED"));
    }

    @Test
    void qualityFailureIsHttp200WithErrorCodeAndNotCounted() throws Exception {
        TestUser user = newUser(true);
        String body = upload(user, TestImages.tinyJpeg(), "current", "front", "image/jpeg")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        long tiny = ((Number) com.jayway.jsonpath.JsonPath.read(body, "$.photo_id")).longValue();
        long id = readId(postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + tiny + "}")
                .andExpect(status().isAccepted()), "$.analysis_id");
        asyncRunner.drain();
        getAs(user, "/api/body-analyses/" + id).andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("failed"))
                .andExpect(jsonPath("$.error_code").value("NO_PERSON"))
                .andExpect(jsonPath("$.error_message").isNotEmpty())
                .andExpect(jsonPath("$.measures").doesNotExist());
        getAs(user, "/api/body-analyses/usage").andExpect(jsonPath("$.used").value(0));
    }

    @Test
    void listsHistoryNewestFirstAndHidesOthers() throws Exception {
        TestUser user = newUser(true);
        long photo = front(user, 12);
        long first = readId(postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}")
                .andExpect(status().isAccepted()), "$.analysis_id");
        asyncRunner.drain();
        long second = readId(postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}")
                .andExpect(status().isAccepted()), "$.analysis_id");
        asyncRunner.drain();
        getAs(user, "/api/body-analyses").andExpect(status().isOk()).andExpect(jsonPath("$.total").value(2))
                .andExpect(jsonPath("$.items[0].analysis_id").value(second))
                .andExpect(jsonPath("$.items[1].analysis_id").value(first))
                .andExpect(jsonPath("$.items[0].status").value("done"))
                .andExpect(jsonPath("$.items[0].source").value("photo"));
        getAs(user, "/api/body-analyses?page_size=51").andExpect(status().isBadRequest());
        TestUser other = newUser(true);
        getAs(other, "/api/body-analyses/" + first).andExpect(status().isNotFound());
        getAs(other, "/api/body-analyses").andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void deletingPhotoKeepsAnalysisAndNullsPhotoId() throws Exception {
        TestUser user = newUser(true);
        long photo = front(user, 13);
        long id = readId(postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}")
                .andExpect(status().isAccepted()), "$.analysis_id");
        asyncRunner.drain();
        deleteAs(user, "/api/photos/" + photo).andExpect(status().isNoContent());
        getAs(user, "/api/body-analyses/" + id).andExpect(jsonPath("$.status").value("done"))
                .andExpect(jsonPath("$.photo_id").doesNotExist())
                .andExpect(jsonPath("$.measures.shoulder_tilt_deg").isNumber());
    }

    @Test
    void requiresBothConsentsAndRevokingCancelsPending() throws Exception {
        TestUser user = newUser(true);
        long photo = front(user, 14);
        long id = readId(postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}")
                .andExpect(status().isAccepted()), "$.analysis_id");
        patchAs(user, "/api/users/me", "{\"ai_processing_agreed\":false}").andExpect(status().isOk());
        getAs(user, "/api/body-analyses/" + id).andExpect(jsonPath("$.status").value("failed"))
                .andExpect(jsonPath("$.error_code").value("AI_FAILED"));
        asyncRunner.drain();
        getAs(user, "/api/body-analyses/" + id).andExpect(jsonPath("$.status").value("failed"));
        postAs(user, "/api/body-analyses/photo", "{\"photo_id\":" + photo + "}").andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("CONSENT_REQUIRED"));
        getAs(user, "/api/body-analyses/" + id).andExpect(status().isOk());
    }
}
