package com.asdf.board.be;

import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.global.security.TokenService;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.entity.UserProfile;
import com.asdf.board.be.user.repository.UserConsentRepository;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@EnabledIfEnvironmentVariable(named = "DB_URL", matches = ".+")
class AuthApiTest {

    private static final String RUN = UUID.randomUUID().toString().substring(0, 8);

    @Autowired MockMvc mvc;
    @Autowired UserRepository userRepository;
    @Autowired UserConsentRepository consentRepository;
    @Autowired UserProfileRepository profileRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired TokenService tokenService;

    private static String signupBody(String email, String password, String nickname, boolean terms) {
        return """
                {"email":"%s","password":"%s","nickname":"%s",
                 "terms_agreed":%s,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true}
                """.formatted(email, password, nickname, terms);
    }

    private ResultActions signup(String body) throws Exception {
        return mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password)));
    }

    @Test
    void signupCreatesUserWithHashedPasswordAndFourConsents() throws Exception {
        signup(signupBody(" Ji.Han" + RUN + "@Example.COM ", "abcd1234", " 지한" + RUN + " ", true))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.user_id").isNumber())
                .andExpect(jsonPath("$.email").value("ji.han" + RUN + "@example.com"))
                .andExpect(jsonPath("$.nickname").value("지한" + RUN))
                .andExpect(jsonPath("$.created_at").value(org.hamcrest.Matchers.matchesPattern(
                        "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\+09:00")))
                .andExpect(jsonPath("$.password").doesNotExist())
                .andExpect(jsonPath("$.access_token").doesNotExist());

        User saved = userRepository.findByEmail("ji.han" + RUN + "@example.com").orElseThrow();
        assertThat(saved.getPasswordHash()).startsWith("$2").isNotEqualTo("abcd1234");
        assertThat(passwordEncoder.matches("abcd1234", saved.getPasswordHash())).isTrue();
        assertThat(saved.getAuthProvider()).isEqualTo(User.AuthProvider.email);

        List<UserConsent> consents = consentRepository.findAll().stream()
                .filter(c -> c.getUser().getId().equals(saved.getId())).toList();
        assertThat(consents).hasSize(4);
        assertThat(consents).extracting(UserConsent::getConsentType)
                .containsExactlyInAnyOrder(UserConsent.ConsentType.values());
        assertThat(consents).allSatisfy(c -> {
            assertThat(c.getAgreed()).isTrue();
            assertThat(c.getSource()).isEqualTo(UserConsent.Source.signup);
            assertThat(c.getPolicyVersion()).isEqualTo("2026-10-01");
        });
    }

    @Test
    void signupStoresRequestedPolicyVersion() throws Exception {
        signup("""
                {"email":"v%s@example.com","password":"abcd1234","nickname":"버전%s",
                 "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true,
                 "policy_version":"2026-12-01"}
                """.formatted(RUN, RUN)).andExpect(status().isCreated());
        assertThat(consentRepository.findAll()).extracting(UserConsent::getPolicyVersion).contains("2026-12-01");
    }

    @Test
    void signupRequiresAllFourConsents() throws Exception {
        signup(signupBody("t" + RUN + "@example.com", "abcd1234", "동의" + RUN, false))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("TERMS_REQUIRED"))
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.fields").isEmpty());
        assertThat(userRepository.existsByEmail("t" + RUN + "@example.com")).isFalse();
    }

    @Test
    void signupReportsEachInvalidFieldInSnakeCase() throws Exception {
        signup("""
                {"email":"not-an-email","password":"short","nickname":"a",
                 "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true}
                """)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fields[?(@.field=='email')]").exists())
                .andExpect(jsonPath("$.fields[?(@.field=='password')].reason").value("8자 이상 영문+숫자 조합이어야 합니다."))
                .andExpect(jsonPath("$.fields[?(@.field=='nickname')]").exists())
                .andExpect(jsonPath("$.fields[?(@.field=='ai_processing_agreed')]").exists());
    }

    @Test
    void passwordMustContainLetterAndDigit() throws Exception {
        signup(signupBody("p1" + RUN + "@example.com", "abcdefgh", "문자만" + RUN, true)).andExpect(status().isBadRequest());
        signup(signupBody("p2" + RUN + "@example.com", "12345678", "숫자만" + RUN, true)).andExpect(status().isBadRequest());
        signup(signupBody("p3" + RUN + "@example.com", "abcd1234", "정상" + RUN, true)).andExpect(status().isCreated());
    }

    @Test
    void malformedJsonIsValidationFailed() throws Exception {
        signup("{not json").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    void duplicateEmailIsConflictEvenWithDifferentCase() throws Exception {
        signup(signupBody("dup" + RUN + "@example.com", "abcd1234", "첫째" + RUN, true)).andExpect(status().isCreated());
        signup(signupBody("DUP" + RUN + "@example.com", "abcd1234", "둘째" + RUN, true))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_DUPLICATED"));
    }

    @Test
    void duplicateNicknameIsConflict() throws Exception {
        signup(signupBody("n1" + RUN + "@example.com", "abcd1234", "같은닉" + RUN, true)).andExpect(status().isCreated());
        signup(signupBody("n2" + RUN + "@example.com", "abcd1234", "같은닉" + RUN, true))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("NICKNAME_DUPLICATED"));
    }

    @Test
    void loginReturnsBearerTokenAndOnboardingFlag() throws Exception {
        signup(signupBody("login" + RUN + "@example.com", "abcd1234", "로그인" + RUN, true)).andExpect(status().isCreated());

        login("Login" + RUN + "@Example.com", "abcd1234")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.access_token").isString())
                .andExpect(jsonPath("$.token_type").value("Bearer"))
                .andExpect(jsonPath("$.expires_in").value(604800))
                .andExpect(jsonPath("$.onboarding_completed").value(false));

        User user = userRepository.findByEmail("login" + RUN + "@example.com").orElseThrow();
        profileRepository.save(UserProfile.builder()
                .user(user)
                .heightCm(new BigDecimal("175.0"))
                .weightKg(new BigDecimal("73.0"))
                .age(18)
                .goalType(UserProfile.GoalType.muscle)
                .weeklyFrequency(5)
                .experienceLevel(ExperienceLevel.over1y)
                .build());

        login("login" + RUN + "@example.com", "abcd1234")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboarding_completed").value(true));
    }

    @Test
    void wrongPasswordAndUnknownEmailGiveTheSameError() throws Exception {
        signup(signupBody("real" + RUN + "@example.com", "abcd1234", "실제" + RUN, true)).andExpect(status().isCreated());

        String wrongPassword = login("real" + RUN + "@example.com", "wrong1234")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"))
                .andReturn().getResponse().getContentAsString();
        String unknownEmail = login("ghost" + RUN + "@example.com", "abcd1234")
                .andExpect(status().isUnauthorized())
                .andReturn().getResponse().getContentAsString();
        assertThat(unknownEmail).isEqualTo(wrongPassword);
    }

    @Test
    void withdrawnUserCannotLogin() throws Exception {
        signup(signupBody("gone" + RUN + "@example.com", "abcd1234", "탈퇴" + RUN, true)).andExpect(status().isCreated());
        User user = userRepository.findByEmail("gone" + RUN + "@example.com").orElseThrow();
        user.setStatus(User.Status.withdrawn);
        userRepository.flush();

        login("gone" + RUN + "@example.com", "abcd1234")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void loginValidatesRequestBody() throws Exception {
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fields[?(@.field=='email')]").exists())
                .andExpect(jsonPath("$.fields[?(@.field=='password')]").exists());
    }

    @Test
    void staleBearerTokenDoesNotBreakPublicEndpoints() throws Exception {
        mvc.perform(post("/api/users").header("Authorization", "Bearer garbage.token.value")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(signupBody("stale" + RUN + "@example.com", "abcd1234", "만료토큰" + RUN, true)))
                .andExpect(status().isCreated());
        mvc.perform(post("/api/auth/login").header("Authorization", "Bearer garbage.token.value")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"stale" + RUN + "@example.com\",\"password\":\"abcd1234\"}"))
                .andExpect(status().isOk());
    }

    @Test
    void protectedPathsRequireValidTokenOfActiveUser() throws Exception {
        signup(signupBody("tok" + RUN + "@example.com", "abcd1234", "토큰" + RUN, true)).andExpect(status().isCreated());
        User user = userRepository.findByEmail("tok" + RUN + "@example.com").orElseThrow();
        String token = tokenService.issue(user).value();

        mvc.perform(get("/api/probe"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        mvc.perform(get("/api/probe").header("Authorization", "Bearer garbage.token.value"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        mvc.perform(get("/api/probe").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"));

        user.setStatus(User.Status.withdrawn);
        userRepository.flush();
        mvc.perform(get("/api/probe").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }
}
