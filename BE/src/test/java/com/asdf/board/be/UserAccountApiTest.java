package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.support.ApiTestBase;
import org.junit.jupiter.api.Test;

class UserAccountApiTest extends ApiTestBase {

    @Test
    void logoutReturnsNoContentForLoggedInUsersOnly() throws Exception {
        TestUser user = newUser(false);
        postAs(user, "/api/auth/logout", null).andExpect(status().isNoContent());
        postAs(null, "/api/auth/logout", null).andExpect(status().isUnauthorized());
    }

    @Test
    void patchChangesNicknameAndRejectsDuplicates() throws Exception {
        TestUser user = newUser(false);
        TestUser other = newUser(false);
        String otherNick = read(getAs(other, "/api/users/me"), "$.nickname");
        patchAs(user, "/api/users/me", "{\"nickname\":\"" + otherNick + "\"}").andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("NICKNAME_DUPLICATED"));
        String mine = read(getAs(user, "/api/users/me"), "$.nickname");
        patchAs(user, "/api/users/me", "{\"nickname\":\"" + mine + "\"}").andExpect(status().isOk());
        patchAs(user, "/api/users/me", "{\"nickname\":\"새닉네임\"}").andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value("새닉네임"));
        patchAs(user, "/api/users/me", "{\"nickname\":\"가\"}").andExpect(status().isBadRequest());
        patchAs(user, "/api/users/me", "{}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        patchAs(user, "/api/users/me", "{\"terms_agreed\":false}").andExpect(status().isBadRequest());
        patchAs(user, "/api/users/me", "{\"privacy_agreed\":false}").andExpect(status().isBadRequest());
    }

    @Test
    void consentsCanBeRevokedAndRestoredAndAffectConsentCompleted() throws Exception {
        TestUser user = newUser(false);
        getAs(user, "/api/users/me").andExpect(jsonPath("$.consent_completed").value(true));
        patchAs(user, "/api/users/me", "{\"body_photo_agreed\":false}").andExpect(status().isOk())
                .andExpect(jsonPath("$.body_photo_agreed").value(false))
                .andExpect(jsonPath("$.ai_processing_agreed").value(true))
                .andExpect(jsonPath("$.consent_completed").value(false));
        patchAs(user, "/api/users/me", "{\"ai_processing_agreed\":false}").andExpect(status().isOk())
                .andExpect(jsonPath("$.ai_processing_agreed").value(false));
        patchAs(user, "/api/users/me", "{\"body_photo_agreed\":true,\"ai_processing_agreed\":true}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.consent_completed").value(true));
        patchAs(user, "/api/users/me", "{\"terms_agreed\":true}").andExpect(status().isOk());
    }

    @Test
    void withdrawalCutsAccessDeletesDataAndAllowsSameEmailAgain() throws Exception {
        TestUser user = newUser(true);
        uploadPhoto(user, "current", "front", 1);
        deleteAs(newUser(false), "/api/users/me").andExpect(status().isNoContent());
        deleteAs(user, "/api/users/me").andExpect(status().isNoContent());
        getAs(user, "/api/users/me").andExpect(status().isUnauthorized());
        getAs(user, "/api/photos").andExpect(status().isUnauthorized());
        assertThat(userRepository.findByEmail(user.email())).isEmpty();
        String verification = com.asdf.board.be.support.EmailTokens.verifiedToken(mvc, mailSender, clock, user.email());
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/users")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON).content("""
                        {"email":"%s","password":"abcd1234","nickname":"재가입",
                         "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true,
                         "email_verification_token":"%s"}
                        """.formatted(user.email(), verification)))
                .andExpect(status().isCreated());
    }
}
