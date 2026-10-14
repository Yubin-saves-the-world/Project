package com.asdf.board.be;

import com.asdf.board.be.support.CapturingMailSender;
import com.asdf.board.be.support.MutableClock;
import com.asdf.board.be.support.TestMailConfig;
import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestMailConfig.class)
@Transactional
@org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable(named = "DB_URL", matches = ".+")
class EmailVerificationApiTest {

    @Autowired MockMvc mvc;
    @Autowired CapturingMailSender mailSender;
    @Autowired MutableClock clock;

    private static String newEmail() {
        return "ev" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
    }

    private ResultActions sendCode(String email) throws Exception {
        return mvc.perform(post("/api/auth/email-verifications").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\"}".formatted(email)));
    }

    private ResultActions confirm(String email, String code) throws Exception {
        return mvc.perform(post("/api/auth/email-verifications/confirm").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"code\":\"%s\"}".formatted(email, code)));
    }

    private ResultActions signup(String email, String nickname, String token) throws Exception {
        return mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"%s","password":"abcd1234","nickname":"%s",
                 "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true,
                 "email_verification_token":"%s"}
                """.formatted(email, nickname, token)));
    }

    private static String wrong(String code) {
        return "000000".equals(code) ? "111111" : "000000";
    }

    @Test
    void sendCodeMailsSixDigits() throws Exception {
        String email = newEmail();
        sendCode(email).andExpect(status().isNoContent());
        assertThat(mailSender.lastCode(email)).matches("\\d{6}");
        assertThat(mailSender.sendCount(email)).isEqualTo(1);
    }

    @Test
    void emailIsNormalizedBeforeSending() throws Exception {
        String email = newEmail();
        sendCode("  " + email.toUpperCase() + " ").andExpect(status().isNoContent());
        assertThat(mailSender.lastCode(email)).isNotNull();
    }

    @Test
    void invalidEmailIsRejected() throws Exception {
        sendCode("not-an-email").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fields[?(@.field=='email')]").exists());
    }

    @Test
    void alreadyRegisteredEmailIsConflict() throws Exception {
        String email = newEmail();
        sendCode(email).andExpect(status().isNoContent());
        String token = JsonPath.read(confirm(email, mailSender.lastCode(email))
                .andReturn().getResponse().getContentAsString(), "$.verification_token");
        signup(email, "중복" + UUID.randomUUID().toString().substring(0, 6), token).andExpect(status().isCreated());

        sendCode(email).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_DUPLICATED"));
    }

    @Test
    void resendIsBlockedWithinSixtySeconds() throws Exception {
        String email = newEmail();
        sendCode(email).andExpect(status().isNoContent());
        sendCode(email).andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_TOO_FREQUENT"));
        assertThat(mailSender.sendCount(email)).isEqualTo(1);

        clock.advance(Duration.ofSeconds(61));
        sendCode(email).andExpect(status().isNoContent());
        assertThat(mailSender.sendCount(email)).isEqualTo(2);
    }

    @Test
    void hourlyLimitIsFiveSends() throws Exception {
        String email = newEmail();
        for (int i = 0; i < 5; i++) {
            sendCode(email).andExpect(status().isNoContent());
            clock.advance(Duration.ofSeconds(61));
        }
        sendCode(email).andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_TOO_FREQUENT"));

        clock.advance(Duration.ofHours(1));
        sendCode(email).andExpect(status().isNoContent());
    }

    @Test
    void wrongCodeIsInvalidAndFifthMistakeLocks() throws Exception {
        String email = newEmail();
        sendCode(email).andExpect(status().isNoContent());
        String bad = wrong(mailSender.lastCode(email));

        for (int i = 0; i < 4; i++) {
            confirm(email, bad).andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("EMAIL_CODE_INVALID"));
        }
        confirm(email, bad).andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_LOCKED"));
        confirm(email, mailSender.lastCode(email)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_EXPIRED"));
    }

    @Test
    void codeExpiresAfterFiveMinutes() throws Exception {
        String email = newEmail();
        sendCode(email).andExpect(status().isNoContent());
        clock.advance(Duration.ofMinutes(5).plusSeconds(1));
        confirm(email, mailSender.lastCode(email)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_EXPIRED"));
    }

    @Test
    void confirmWithoutRequestIsExpired() throws Exception {
        confirm(newEmail(), "123456").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_EXPIRED"));
    }

    @Test
    void confirmValidatesCodeFormat() throws Exception {
        confirm(newEmail(), "12ab").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fields[?(@.field=='code')]").exists());
    }

    @Test
    void newCodeInvalidatesThePreviousOne() throws Exception {
        String email = newEmail();
        sendCode(email).andExpect(status().isNoContent());
        String first = mailSender.lastCode(email);
        clock.advance(Duration.ofSeconds(61));
        sendCode(email).andExpect(status().isNoContent());
        String second = mailSender.lastCode(email);

        if (!first.equals(second)) {
            confirm(email, first).andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("EMAIL_CODE_INVALID"));
        }
        confirm(email, second).andExpect(status().isOk());
    }

    @Test
    void tokenWorksOnceAndOnlyForItsOwnEmail() throws Exception {
        String email = newEmail();
        sendCode(email).andExpect(status().isNoContent());
        String body = confirm(email, mailSender.lastCode(email)).andExpect(status().isOk())
                .andExpect(jsonPath("$.expires_in").value(1800))
                .andReturn().getResponse().getContentAsString();
        String token = JsonPath.read(body, "$.verification_token");
        String suffix = UUID.randomUUID().toString().substring(0, 6);

        signup(newEmail(), "다른" + suffix, token).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"));
        signup(email, "첫째" + suffix, "wrong-token").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"));
        signup(email, "첫째" + suffix, token).andExpect(status().isCreated());
        signup(email, "둘째" + suffix, token).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"));
    }

    @Test
    void tokenExpiresAfterThirtyMinutes() throws Exception {
        String email = newEmail();
        sendCode(email).andExpect(status().isNoContent());
        String token = JsonPath.read(confirm(email, mailSender.lastCode(email))
                .andReturn().getResponse().getContentAsString(), "$.verification_token");

        clock.advance(Duration.ofMinutes(30).plusSeconds(1));
        signup(email, "만료" + UUID.randomUUID().toString().substring(0, 6), token).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_NOT_VERIFIED"));
    }

    @Test
    void signupRequiresTokenField() throws Exception {
        mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"%s","password":"abcd1234","nickname":"토큰없음",
                 "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true}
                """.formatted(newEmail())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fields[?(@.field=='email_verification_token')]").exists());
    }
}
