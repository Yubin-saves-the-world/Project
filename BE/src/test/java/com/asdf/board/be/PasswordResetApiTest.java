package com.asdf.board.be;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.auth.mail.MailPurpose;
import com.asdf.board.be.support.CapturingMailSender;
import com.asdf.board.be.support.EmailTokens;
import com.asdf.board.be.support.MutableClock;
import com.asdf.board.be.support.TestMailConfig;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestMailConfig.class)
@Transactional
@org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable(named = "DB_URL", matches = ".+")
class PasswordResetApiTest {

    private static final String OLD_PASSWORD = "abcd1234";
    private static final String NEW_PASSWORD = "newpass99";

    @Autowired MockMvc mvc;
    @Autowired CapturingMailSender mailSender;
    @Autowired MutableClock clock;
    @Autowired UserRepository userRepository;

    private static String newEmail() {
        return "pr" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
    }

    private String signedUp() throws Exception {
        String email = newEmail();
        String token = EmailTokens.verifiedToken(mvc, mailSender, clock, email);
        mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content("""
                        {"email":"%s","password":"%s","nickname":"%s",
                         "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true,
                         "email_verification_token":"%s"}
                        """.formatted(email, OLD_PASSWORD, "u" + UUID.randomUUID().toString().substring(0, 8), token)))
                .andExpect(status().isCreated());
        clock.advance(Duration.ofMinutes(2));
        return email;
    }

    private ResultActions requestReset(String email) throws Exception {
        return mvc.perform(post("/api/auth/password/reset-request").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\"}".formatted(email)));
    }

    private ResultActions verify(String email, String code) throws Exception {
        return mvc.perform(post("/api/auth/password/reset-verification").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"code\":\"%s\"}".formatted(email, code)));
    }

    private ResultActions reset(String token, String password) throws Exception {
        return mvc.perform(patch("/api/auth/password/reset").contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"%s\",\"new_password\":\"%s\"}".formatted(token, password)));
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password)));
    }

    private String resetToken(String email) throws Exception {
        requestReset(email).andExpect(status().isNoContent());
        String body = verify(email, mailSender.lastCode(email))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.expires_in").value(1800))
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.reset_token");
    }

    private static String wrong(String code) {
        return "000000".equals(code) ? "111111" : "000000";
    }

    @Test
    void fullFlowChangesPassword() throws Exception {
        String email = signedUp();
        String token = resetToken(email);
        assertThat(mailSender.lastPurpose(email)).isEqualTo(MailPurpose.PASSWORD_RESET);

        reset(token, NEW_PASSWORD).andExpect(status().isNoContent());

        login(email, OLD_PASSWORD).andExpect(status().isUnauthorized());
        login(email, NEW_PASSWORD).andExpect(status().isOk())
                .andExpect(jsonPath("$.access_token").isNotEmpty());
    }

    @Test
    void unknownEmailGetsNoContentAndNoMail() throws Exception {
        String email = newEmail();
        requestReset(email).andExpect(status().isNoContent());
        assertThat(mailSender.sendCount(email)).isZero();
    }

    @Test
    void socialAccountGetsNoContentAndNoMail() throws Exception {
        String email = newEmail();
        userRepository.save(User.builder()
                .email(email)
                .nickname("g" + UUID.randomUUID().toString().substring(0, 8))
                .authProvider(User.AuthProvider.google)
                .googleSub(UUID.randomUUID().toString().replace("-", ""))
                .build());
        requestReset(email).andExpect(status().isNoContent());
        assertThat(mailSender.sendCount(email)).isZero();
    }

    @Test
    void emailIsNormalized() throws Exception {
        String email = signedUp();
        requestReset("  " + email.toUpperCase() + " ").andExpect(status().isNoContent());
        assertThat(mailSender.lastCode(email)).matches("\\d{6}");
    }

    @Test
    void invalidEmailIsRejected() throws Exception {
        requestReset("not-an-email").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    void secondRequestWithinIntervalSendsNothingButStillNoContent() throws Exception {
        String email = signedUp();
        int before = mailSender.sendCount(email);
        requestReset(email).andExpect(status().isNoContent());
        requestReset(email).andExpect(status().isNoContent());
        assertThat(mailSender.sendCount(email)).isEqualTo(before + 1);

        clock.advance(Duration.ofSeconds(61));
        requestReset(email).andExpect(status().isNoContent());
        assertThat(mailSender.sendCount(email)).isEqualTo(before + 2);
    }

    @Test
    void wrongCodeIsRejectedAndRightCodeStillWorks() throws Exception {
        String email = signedUp();
        requestReset(email).andExpect(status().isNoContent());
        String code = mailSender.lastCode(email);

        verify(email, wrong(code)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_INVALID"));
        verify(email, code).andExpect(status().isOk());
    }

    @Test
    void fiveWrongCodesLockTheRequest() throws Exception {
        String email = signedUp();
        requestReset(email).andExpect(status().isNoContent());
        String code = mailSender.lastCode(email);

        for (int i = 0; i < 4; i++) {
            verify(email, wrong(code)).andExpect(jsonPath("$.code").value("EMAIL_CODE_INVALID"));
        }
        verify(email, wrong(code)).andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_LOCKED"));
        verify(email, code).andExpect(jsonPath("$.code").value("EMAIL_CODE_EXPIRED"));
    }

    @Test
    void codeExpiresAfterFiveMinutes() throws Exception {
        String email = signedUp();
        requestReset(email).andExpect(status().isNoContent());
        String code = mailSender.lastCode(email);

        clock.advance(Duration.ofMinutes(5).plusSeconds(1));
        verify(email, code).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_EXPIRED"));
    }

    @Test
    void verifyForUnknownEmailLooksLikeNeverRequested() throws Exception {
        verify(newEmail(), "123456").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("EMAIL_CODE_EXPIRED"));
    }

    @Test
    void resetTokenWorksOnlyOnce() throws Exception {
        String email = signedUp();
        String token = resetToken(email);
        reset(token, NEW_PASSWORD).andExpect(status().isNoContent());
        reset(token, "another99pw").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("RESET_TOKEN_INVALID"));
        login(email, NEW_PASSWORD).andExpect(status().isOk());
    }

    @Test
    void resetTokenExpiresAfterThirtyMinutes() throws Exception {
        String email = signedUp();
        String token = resetToken(email);
        clock.advance(Duration.ofMinutes(30).plusSeconds(1));
        reset(token, NEW_PASSWORD).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("RESET_TOKEN_INVALID"));
        login(email, OLD_PASSWORD).andExpect(status().isOk());
    }

    @Test
    void newerTokenInvalidatesOlderOne() throws Exception {
        String email = signedUp();
        String first = resetToken(email);
        clock.advance(Duration.ofSeconds(61));
        String second = resetToken(email);

        reset(first, NEW_PASSWORD).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("RESET_TOKEN_INVALID"));
        reset(second, NEW_PASSWORD).andExpect(status().isNoContent());
    }

    @Test
    void weakPasswordIsRejectedWithoutConsumingToken() throws Exception {
        String email = signedUp();
        String token = resetToken(email);

        reset(token, "short").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fields[0].field").value("new_password"));
        reset(token, "onlyletters").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        reset(token, NEW_PASSWORD).andExpect(status().isNoContent());
    }

    @Test
    void unknownTokenIsRejected() throws Exception {
        reset("this-token-was-never-issued-by-the-server", NEW_PASSWORD).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("RESET_TOKEN_INVALID"));
    }

    @Test
    void endpointsArePublic() throws Exception {
        mvc.perform(post("/api/auth/password/reset-request").contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer not-a-real-token")
                        .content("{\"email\":\"%s\"}".formatted(newEmail())))
                .andExpect(status().isNoContent());
    }
}
