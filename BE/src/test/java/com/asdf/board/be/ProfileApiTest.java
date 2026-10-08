package com.asdf.board.be;

import com.asdf.board.be.global.security.TokenService;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.entity.UserProfile;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
@EnabledIfEnvironmentVariable(named = "DB_URL", matches = ".+")
class ProfileApiTest {

    private static final String PROFILE = "/api/users/me/profile";
    private static final String VALID = """
            {"height_cm":175.0,"weight_kg":73.5,"age":18,"gender":"male",
             "goal_type":"muscle","weekly_frequency":5,"experience_level":"over1y"}
            """;

    @PersistenceContext EntityManager em;
    @Autowired MockMvc mvc;
    @Autowired UserRepository userRepository;
    @Autowired UserProfileRepository profileRepository;
    @Autowired TokenService tokenService;

    private String newUserToken() throws Exception {
        String run = UUID.randomUUID().toString().substring(0, 8);
        mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"p%s@example.com","password":"abcd1234","nickname":"설문%s",
                 "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true}
                """.formatted(run, run))).andExpect(status().isCreated());
        User user = userRepository.findByEmail("p" + run + "@example.com").orElseThrow();
        return tokenService.issue(user).value();
    }

    private ResultActions send(String method, String token, String body) throws Exception {
        var builder = method.equals("POST") ? post(PROFILE) : patch(PROFILE);
        return mvc.perform(builder.header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions read(String token) throws Exception {
        return mvc.perform(get(PROFILE).header("Authorization", "Bearer " + token));
    }

    private ResultActions me(String token) throws Exception {
        return mvc.perform(get("/api/users/me").header("Authorization", "Bearer " + token));
    }

    @Test
    void profileEndpointsRequireLogin() throws Exception {
        mvc.perform(post(PROFILE).contentType(MediaType.APPLICATION_JSON).content(VALID))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        mvc.perform(get(PROFILE)).andExpect(status().isUnauthorized());
        mvc.perform(patch(PROFILE).contentType(MediaType.APPLICATION_JSON).content("{\"age\":20}"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/users/me")).andExpect(status().isUnauthorized());
    }

    @Test
    void createStoresProfileAndFlipsOnboardingFlag() throws Exception {
        String token = newUserToken();

        me(token).andExpect(status().isOk())
                .andExpect(jsonPath("$.onboarding_completed").value(false))
                .andExpect(jsonPath("$.consent_completed").value(true))
                .andExpect(jsonPath("$.body_photo_agreed").value(true))
                .andExpect(jsonPath("$.ai_processing_agreed").value(true))
                .andExpect(jsonPath("$.role").value("user"))
                .andExpect(jsonPath("$.nickname").value(org.hamcrest.Matchers.startsWith("설문")))
                .andExpect(jsonPath("$.user_id").isNumber());

        send("POST", token, VALID)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.profile_id").isNumber())
                .andExpect(jsonPath("$.height_cm").value(175.0))
                .andExpect(jsonPath("$.weight_kg").value(73.5))
                .andExpect(jsonPath("$.age").value(18))
                .andExpect(jsonPath("$.gender").value("male"))
                .andExpect(jsonPath("$.goal_type").value("muscle"))
                .andExpect(jsonPath("$.weekly_frequency").value(5))
                .andExpect(jsonPath("$.experience_level").value("over1y"))
                .andExpect(jsonPath("$.measured_at").value(org.hamcrest.Matchers.matchesPattern(
                        "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\+09:00")));

        me(token).andExpect(jsonPath("$.onboarding_completed").value(true));
        read(token).andExpect(status().isOk()).andExpect(jsonPath("$.weight_kg").value(73.5));
    }

    @Test
    void genderDefaultsToNoneWhenOmitted() throws Exception {
        send("POST", newUserToken(), """
                {"height_cm":170,"weight_kg":65,"age":18,"goal_type":"diet",
                 "weekly_frequency":3,"experience_level":"under3m"}
                """)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.gender").value("none"))
                .andExpect(jsonPath("$.height_cm").value(170.0));
    }

    @Test
    void secondCreateIsConflictAndKeepsFirstRow() throws Exception {
        String token = newUserToken();
        send("POST", token, VALID).andExpect(status().isCreated());
        send("POST", token, VALID.replace("73.5", "80.0"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PROFILE_ALREADY_EXISTS"));
        read(token).andExpect(jsonPath("$.weight_kg").value(73.5));
    }

    @Test
    void getBeforeCreateIsNotFound() throws Exception {
        read(newUserToken()).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("PROFILE_NOT_FOUND"));
    }

    @Test
    void outOfRangeValuesAreRejectedPerField() throws Exception {
        send("POST", newUserToken(), """
                {"height_cm":99,"weight_kg":251,"age":9,"goal_type":"muscle",
                 "weekly_frequency":8,"experience_level":"over1y"}
                """)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fields[?(@.field=='height_cm')]").exists())
                .andExpect(jsonPath("$.fields[?(@.field=='weight_kg')]").exists())
                .andExpect(jsonPath("$.fields[?(@.field=='age')]").exists())
                .andExpect(jsonPath("$.fields[?(@.field=='weekly_frequency')]").exists());
    }

    @Test
    void boundaryValuesAreAccepted() throws Exception {
        send("POST", newUserToken(), """
                {"height_cm":100,"weight_kg":250,"age":10,"goal_type":"posture",
                 "weekly_frequency":1,"experience_level":"under1y"}
                """).andExpect(status().isCreated());
        send("POST", newUserToken(), """
                {"height_cm":250,"weight_kg":30,"age":100,"goal_type":"posture",
                 "weekly_frequency":7,"experience_level":"under1y"}
                """).andExpect(status().isCreated());
    }

    @Test
    void requiredFieldsAndDecimalsAreChecked() throws Exception {
        send("POST", newUserToken(), "{}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fields[?(@.field=='height_cm')]").exists())
                .andExpect(jsonPath("$.fields[?(@.field=='goal_type')]").exists())
                .andExpect(jsonPath("$.fields[?(@.field=='experience_level')]").exists());
        send("POST", newUserToken(), VALID.replace("175.0", "175.55"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fields[?(@.field=='height_cm')]").exists());
    }

    @Test
    void unknownEnumValueIsValidationFailed() throws Exception {
        send("POST", newUserToken(), VALID.replace("muscle", "bulk"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    void patchAddsHistoryRowAndInheritsOmittedFields() throws Exception {
        String token = newUserToken();
        send("POST", token, VALID).andExpect(status().isCreated());
        Long userId = userRepository.findAll().stream()
                .filter(u -> u.getEmail() != null && u.getEmail().startsWith("p")).map(User::getId)
                .max(Long::compare).orElseThrow();

        send("PATCH", token, "{\"weight_kg\":71.0}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.weight_kg").value(71.0))
                .andExpect(jsonPath("$.height_cm").value(175.0))
                .andExpect(jsonPath("$.goal_type").value("muscle"))
                .andExpect(jsonPath("$.routine_refresh_recommended").value(false));

        assertThat(profileRepository.findAll().stream().filter(p -> p.getUser().getId().equals(userId)))
                .hasSize(2);
        read(token).andExpect(jsonPath("$.weight_kg").value(71.0));
    }

    @Test
    void patchRecommendsRoutineRefreshOnlyWhenPlanFieldsChange() throws Exception {
        String token = newUserToken();
        send("POST", token, VALID).andExpect(status().isCreated());

        send("PATCH", token, "{\"goal_type\":\"diet\"}")
                .andExpect(jsonPath("$.routine_refresh_recommended").value(true));
        send("PATCH", token, "{\"weekly_frequency\":3}")
                .andExpect(jsonPath("$.routine_refresh_recommended").value(true));
        send("PATCH", token, "{\"experience_level\":\"under1y\"}")
                .andExpect(jsonPath("$.routine_refresh_recommended").value(true));
        send("PATCH", token, "{\"goal_type\":\"diet\",\"age\":19}")
                .andExpect(jsonPath("$.routine_refresh_recommended").value(false))
                .andExpect(jsonPath("$.age").value(19));
    }

    @Test
    void patchNeedsAtLeastOneFieldAndAnExistingProfile() throws Exception {
        String token = newUserToken();
        send("PATCH", token, "{\"age\":20}")
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("PROFILE_NOT_FOUND"));

        send("POST", token, VALID).andExpect(status().isCreated());
        send("PATCH", token, "{}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        send("PATCH", token, "{\"age\":5}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fields[?(@.field=='age')]").exists());
    }

    @Test
    void usersCannotSeeEachOthersProfile() throws Exception {
        String owner = newUserToken();
        String other = newUserToken();
        send("POST", owner, VALID).andExpect(status().isCreated());

        read(other).andExpect(status().isNotFound());
        me(other).andExpect(jsonPath("$.onboarding_completed").value(false));
        send("PATCH", other, "{\"age\":30}").andExpect(status().isNotFound());
        read(owner).andExpect(jsonPath("$.age").value(18));
    }

    @Test
    void loginReflectsOnboardingAfterProfileCreate() throws Exception {
        String run = UUID.randomUUID().toString().substring(0, 8);
        String email = "flow" + run + "@example.com";
        mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"%s","password":"abcd1234","nickname":"흐름%s",
                 "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true}
                """.formatted(email, run))).andExpect(status().isCreated());

        String loginBody = "{\"email\":\"%s\",\"password\":\"abcd1234\"}".formatted(email);
        String token = com.jayway.jsonpath.JsonPath.read(
                mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(loginBody))
                        .andExpect(jsonPath("$.onboarding_completed").value(false))
                        .andReturn().getResponse().getContentAsString(),
                "$.access_token");

        send("POST", token, VALID).andExpect(status().isCreated());

        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content(loginBody))
                .andExpect(jsonPath("$.onboarding_completed").value(true));
    }

    @Test
    void timestampsInResponsesMatchWhatIsStored() throws Exception {
        String run = UUID.randomUUID().toString().substring(0, 8);
        String email = "ts" + run + "@example.com";
        String createdAt = com.jayway.jsonpath.JsonPath.read(
                mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content("""
                                {"email":"%s","password":"abcd1234","nickname":"시각%s",
                                 "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true}
                                """.formatted(email, run)))
                        .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString(),
                "$.created_at");
        String token = tokenService.issue(userRepository.findByEmail(email).orElseThrow()).value();
        em.flush();
        em.clear();
        me(token).andExpect(jsonPath("$.created_at").value(createdAt));

        String measuredAt = com.jayway.jsonpath.JsonPath.read(
                send("POST", token, VALID).andExpect(status().isCreated()).andReturn().getResponse().getContentAsString(),
                "$.measured_at");
        em.flush();
        em.clear();
        read(token).andExpect(jsonPath("$.measured_at").value(measuredAt));
    }
}
