package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.support.ApiTestBase;
import com.asdf.board.be.support.TestImages;
import org.junit.jupiter.api.Test;

class GoalBodyApiTest extends ApiTestBase {

    @Test
    void registersGoalByDescriptionOnlyWithoutAi() throws Exception {
        TestUser user = newUser(true);
        postAs(user, "/api/goal-bodies", "{\"description\":\"어깨가 넓은 몸\"}").andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("done"))
                .andExpect(jsonPath("$.description").value("어깨가 넓은 몸"))
                .andExpect(jsonPath("$.summary").doesNotExist())
                .andExpect(jsonPath("$.poll_after_ms").doesNotExist());
        assertThat(asyncRunner.pending()).isZero();
        getAs(user, "/api/goal-bodies").andExpect(status().isOk()).andExpect(jsonPath("$.status").value("done"));
    }

    @Test
    void validatesRequestAndOwnership() throws Exception {
        TestUser user = newUser(true);
        postAs(user, "/api/goal-bodies", "{}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        postAs(user, "/api/goal-bodies", "{\"description\":\"" + "가".repeat(201) + "\"}")
                .andExpect(status().isBadRequest());
        getAs(user, "/api/goal-bodies").andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("GOAL_NOT_FOUND"));
        TestUser fresh = newUser(false);
        postAs(fresh, "/api/goal-bodies", "{\"description\":\"x\"}").andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ONBOARDING_REQUIRED"));
        long current = uploadPhoto(user, "current", "front", 61);
        postAs(user, "/api/goal-bodies", "{\"photo_id\":" + current + "}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("PHOTO_TYPE_MISMATCH"));
        TestUser other = newUser(true);
        long theirs = uploadPhoto(other, "goal", "front", 62);
        postAs(user, "/api/goal-bodies", "{\"photo_id\":" + theirs + "}").andExpect(status().isNotFound());
        postAs(user, "/api/goal-bodies", "{\"photo_id\":999999999}").andExpect(status().isNotFound());
    }

    @Test
    void photoGoalBecomesDoneAndPhotoIsDeleted() throws Exception {
        TestUser user = newUser(true);
        long photo = uploadPhoto(user, "goal", "front", 71);
        postAs(user, "/api/goal-bodies", "{\"photo_id\":" + photo + ",\"description\":\"역삼각형\"}")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("pending"))
                .andExpect(jsonPath("$.poll_after_ms").value(2000));
        getAs(user, "/api/goal-bodies").andExpect(jsonPath("$.status").value("pending"));
        asyncRunner.drain();
        getAs(user, "/api/goal-bodies").andExpect(jsonPath("$.status").value("done"))
                .andExpect(jsonPath("$.summary").value(org.hamcrest.Matchers.containsString("역삼각형")))
                .andExpect(jsonPath("$.poll_after_ms").doesNotExist());
        getAs(user, "/api/photos?type=goal").andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void failedFeatureExtractionStillDeletesPhoto() throws Exception {
        TestUser user = newUser(true);
        String body = upload(user, TestImages.tinyJpeg(), "goal", "front", "image/jpeg").andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        long photo = ((Number) com.jayway.jsonpath.JsonPath.read(body, "$.photo_id")).longValue();
        postAs(user, "/api/goal-bodies", "{\"photo_id\":" + photo + "}").andExpect(status().isCreated());
        asyncRunner.drain();
        getAs(user, "/api/goal-bodies").andExpect(jsonPath("$.status").value("failed"))
                .andExpect(jsonPath("$.error_message").isNotEmpty());
        getAs(user, "/api/photos?type=goal").andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void allowsOnlyOneGoalPerUser() throws Exception {
        TestUser user = newUser(true);
        postAs(user, "/api/goal-bodies", "{\"description\":\"a\"}").andExpect(status().isCreated());
        postAs(user, "/api/goal-bodies", "{\"description\":\"b\"}").andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("GOAL_ALREADY_EXISTS"));
    }

    @Test
    void requiresBothConsentsForPhotoGoals() throws Exception {
        TestUser user = newUser(true, true, true);
        long photo = uploadPhoto(user, "goal", "front", 81);
        patchAs(user, "/api/users/me", "{\"ai_processing_agreed\":false}").andExpect(status().isOk());
        postAs(user, "/api/goal-bodies", "{\"photo_id\":" + photo + "}").andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("CONSENT_REQUIRED"));
        postAs(user, "/api/goal-bodies", "{\"description\":\"설명만\"}").andExpect(status().isCreated());
    }

    @Test
    void patchChangesDescriptionOrRestartsWithNewPhoto() throws Exception {
        TestUser user = newUser(true);
        long id = readId(postAs(user, "/api/goal-bodies", "{\"description\":\"처음\"}")
                .andExpect(status().isCreated()), "$.goal_body_id");
        patchAs(user, "/api/goal-bodies/" + id, "{}").andExpect(status().isBadRequest());
        patchAs(user, "/api/goal-bodies/" + id, "{\"description\":\"바뀜\"}").andExpect(status().isOk())
                .andExpect(jsonPath("$.description").value("바뀜")).andExpect(jsonPath("$.status").value("done"));
        long photo = uploadPhoto(user, "goal", "front", 91);
        patchAs(user, "/api/goal-bodies/" + id, "{\"photo_id\":" + photo + "}").andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("pending"));
        asyncRunner.drain();
        getAs(user, "/api/goal-bodies").andExpect(jsonPath("$.status").value("done"))
                .andExpect(jsonPath("$.summary").isNotEmpty());
        patchAs(newUser(true), "/api/goal-bodies/" + id, "{\"description\":\"x\"}").andExpect(status().isNotFound());
    }

    @Test
    void deleteRemovesGoalAndPendingPhoto() throws Exception {
        TestUser user = newUser(true);
        long photo = uploadPhoto(user, "goal", "front", 101);
        long id = readId(postAs(user, "/api/goal-bodies", "{\"photo_id\":" + photo + "}")
                .andExpect(status().isCreated()), "$.goal_body_id");
        deleteAs(newUser(true), "/api/goal-bodies/" + id).andExpect(status().isNotFound());
        deleteAs(user, "/api/goal-bodies/" + id).andExpect(status().isNoContent());
        asyncRunner.drain();
        getAs(user, "/api/goal-bodies").andExpect(status().isNotFound());
        getAs(user, "/api/photos?type=goal").andExpect(jsonPath("$.total").value(0));
        postAs(user, "/api/goal-bodies", "{\"description\":\"다시\"}").andExpect(status().isCreated());
    }
}
