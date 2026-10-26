package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.support.ApiTestBase;
import com.asdf.board.be.support.TestImages;
import java.time.Duration;
import org.junit.jupiter.api.Test;

class PhotoApiTest extends ApiTestBase {

    @Test
    void requiresLoginAndOnboarding() throws Exception {
        mvc.perform(get("/api/photos")).andExpect(status().isUnauthorized());
        TestUser fresh = newUser(false);
        getAs(fresh, "/api/photos").andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ONBOARDING_REQUIRED"));
        upload(fresh, TestImages.jpeg(1), "current", "front", "image/jpeg").andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ONBOARDING_REQUIRED"));
    }

    @Test
    void uploadsJpegAndPngWithSignedUrl() throws Exception {
        TestUser user = newUser(true);
        upload(user, TestImages.jpeg(2), "current", null, "image/jpeg").andExpect(status().isCreated())
                .andExpect(jsonPath("$.type").value("current"))
                .andExpect(jsonPath("$.side").value("front"))
                .andExpect(jsonPath("$.url").value(org.hamcrest.Matchers.containsString("/api/files/")))
                .andExpect(jsonPath("$.url_expires_at").isNotEmpty())
                .andExpect(jsonPath("$.created_at").isNotEmpty());
        upload(user, TestImages.png(3), "current", "side", "image/png").andExpect(status().isCreated())
                .andExpect(jsonPath("$.side").value("side"));
    }

    @Test
    void rejectsNonImageAndOversizedAndBadParams() throws Exception {
        TestUser user = newUser(true);
        upload(user, "not an image at all".getBytes(), "current", "front", "image/jpeg")
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.code").value("IMAGE_INVALID_TYPE"));
        byte[] big = new byte[10 * 1024 * 1024 + 1];
        big[0] = (byte) 0xFF;
        big[1] = (byte) 0xD8;
        big[2] = (byte) 0xFF;
        upload(user, big, "current", "front", "image/jpeg").andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.code").value("IMAGE_TOO_LARGE"));
        upload(user, TestImages.jpeg(4), "wrong", "front", "image/jpeg").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        upload(user, TestImages.jpeg(4), "current", "diagonal", "image/jpeg").andExpect(status().isBadRequest());
        upload(user, new byte[0], "current", "front", "image/jpeg").andExpect(status().isBadRequest());
    }

    @Test
    void identifiesImagesByContentNotExtensionOrHeader() throws Exception {
        TestUser user = newUser(true);
        upload(user, TestImages.png(5), "current", "front", "text/plain").andExpect(status().isCreated());
    }

    @Test
    void blocksUploadWithoutPhotoConsent() throws Exception {
        TestUser user = newUser(true, false, true);
        upload(user, TestImages.jpeg(6), "current", "front", "image/jpeg").andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("CONSENT_REQUIRED"));
    }

    @Test
    void limitsTwentyPhotosPerUser() throws Exception {
        TestUser user = newUser(true);
        for (int i = 0; i < 20; i++) {
            uploadPhoto(user, "current", "front", 100 + i);
        }
        upload(user, TestImages.jpeg(999), "current", "front", "image/jpeg").andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PHOTO_LIMIT_EXCEEDED"));
    }

    @Test
    void listsNewestFirstWithTypeFilterAndPaging() throws Exception {
        TestUser user = newUser(true);
        long a = uploadPhoto(user, "current", "front", 11);
        long b = uploadPhoto(user, "goal", "front", 12);
        long c = uploadPhoto(user, "current", "side", 13);
        getAs(user, "/api/photos").andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(3))
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.page_size").value(20))
                .andExpect(jsonPath("$.items[0].photo_id").value(c))
                .andExpect(jsonPath("$.items[2].photo_id").value(a));
        getAs(user, "/api/photos?type=goal").andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.items[0].photo_id").value(b));
        getAs(user, "/api/photos?page=2&page_size=2").andExpect(jsonPath("$.items.length()").value(1));
        getAs(user, "/api/photos?page_size=51").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        getAs(user, "/api/photos?page=0").andExpect(status().isBadRequest());
        getAs(user, "/api/photos?type=bad").andExpect(status().isBadRequest());
    }

    @Test
    void servesFilesOnlyThroughValidSignedUrls() throws Exception {
        TestUser user = newUser(true);
        byte[] data = TestImages.jpeg(21);
        String body = upload(user, data, "current", "front", "image/jpeg").andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String url = com.jayway.jsonpath.JsonPath.read(body, "$.url");
        String path = url.substring(url.indexOf("/api/files/"));
        byte[] served = mvc.perform(get(path)).andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                        .content().contentType("image/jpeg"))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(served).isEqualTo(data);
        int sigAt = path.indexOf("sig=") + 4;
        char flipped = path.charAt(sigAt) == '0' ? '1' : '0';
        mvc.perform(get(path.substring(0, sigAt) + flipped + path.substring(sigAt + 1))).andExpect(status().isNotFound());
        mvc.perform(get(path.replaceAll("exp=\\d+", "exp=1"))).andExpect(status().isNotFound());
        advance(Duration.ofHours(2));
        mvc.perform(get(path)).andExpect(status().isNotFound());
    }

    @Test
    void deletesOnePhotoAndOnlyOwnPhotos() throws Exception {
        TestUser user = newUser(true);
        TestUser other = newUser(true);
        long mine = uploadPhoto(user, "current", "front", 31);
        deleteAs(other, "/api/photos/" + mine).andExpect(status().isNotFound());
        deleteAs(user, "/api/photos/" + mine).andExpect(status().isNoContent());
        deleteAs(user, "/api/photos/" + mine).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));
        getAs(user, "/api/photos").andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void deletesAllPhotosOfOneType() throws Exception {
        TestUser user = newUser(true);
        uploadPhoto(user, "current", "front", 41);
        uploadPhoto(user, "current", "side", 42);
        uploadPhoto(user, "goal", "front", 43);
        deleteAs(user, "/api/photos").andExpect(status().isBadRequest());
        deleteAs(user, "/api/photos?type=current").andExpect(status().isOk())
                .andExpect(jsonPath("$.deleted_count").value(2))
                .andExpect(jsonPath("$.skipped_count").value(0));
        getAs(user, "/api/photos").andExpect(jsonPath("$.total").value(1));
    }

    @Test
    void goalPhotoUsedByPendingGoalCannotBeDeleted() throws Exception {
        TestUser user = newUser(true);
        long photo = uploadPhoto(user, "goal", "front", 51);
        postAs(user, "/api/goal-bodies", "{\"photo_id\":" + photo + "}").andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("pending"));
        deleteAs(user, "/api/photos/" + photo).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PHOTO_IN_USE"));
        deleteAs(user, "/api/photos?type=goal").andExpect(jsonPath("$.deleted_count").value(0))
                .andExpect(jsonPath("$.skipped_count").value(1));
    }
}
