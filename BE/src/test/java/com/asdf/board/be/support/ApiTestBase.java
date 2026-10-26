package com.asdf.board.be.support;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.asdf.board.be.global.security.TokenService;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserRepository;
import com.jayway.jsonpath.JsonPath;
import java.time.Duration;
import java.util.UUID;
import java.time.Instant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;

@SpringBootTest
@AutoConfigureMockMvc
@Import({TestMailConfig.class, TestAsyncConfig.class, TestCoachConfig.class})
@Transactional
@EnabledIfEnvironmentVariable(named = "DB_URL", matches = ".+")
public abstract class ApiTestBase {

    public static final String PROFILE_JSON = """
            {"height_cm":175.0,"weight_kg":73.5,"age":18,"gender":"male",
             "goal_type":"muscle","weekly_frequency":4,"experience_level":"under1y"}
            """;

    @Autowired protected MockMvc mvc;
    @Autowired protected UserRepository userRepository;
    @Autowired protected TokenService tokenService;
    @Autowired protected CapturingMailSender mailSender;
    @Autowired protected MutableClock clock;
    @Autowired protected QueueAsyncRunner asyncRunner;
    @Autowired protected TestCoachConfig.ToggleCoachAi coachAi;

    private Instant clockStart;

    @BeforeEach
    void rememberClock() {
        clockStart = clock.instant();
    }

    @AfterEach
    void restoreClock() {
        clock.set(clockStart);
        coachAi.setDown(false);
    }

    public record TestUser(Long id, String email, String token) {
    }

    protected TestUser newUser(boolean onboarded) throws Exception {
        return newUser(onboarded, true, true);
    }

    protected TestUser newUser(boolean onboarded, boolean photoConsent, boolean aiConsent) throws Exception {
        String run = UUID.randomUUID().toString().substring(0, 8);
        String email = "t" + run + "@example.com";
        String verification = EmailTokens.verifiedToken(mvc, mailSender, clock, email);
        mvc.perform(post("/api/users").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"%s","password":"abcd1234","nickname":"유저%s",
                 "terms_agreed":true,"privacy_agreed":true,"body_photo_agreed":true,"ai_processing_agreed":true,
                 "email_verification_token":"%s"}
                """.formatted(email, run, verification))).andExpect(status().isCreated());
        User user = userRepository.findByEmail(email).orElseThrow();
        String token = tokenService.issue(user).value();
        TestUser result = new TestUser(user.getId(), email, token);
        if (onboarded) {
            call(post("/api/users/me/profile"), result, PROFILE_JSON).andExpect(status().isCreated());
        }
        if (!photoConsent || !aiConsent) {
            call(patch("/api/users/me"), result, "{\"body_photo_agreed\":%s,\"ai_processing_agreed\":%s}"
                    .formatted(photoConsent, aiConsent)).andExpect(status().isOk());
        }
        return result;
    }

    protected ResultActions call(MockHttpServletRequestBuilder builder, TestUser user, String json) throws Exception {
        MockHttpServletRequestBuilder request = builder;
        if (user != null) {
            request = request.header("Authorization", "Bearer " + user.token());
        }
        if (json != null) {
            request = request.contentType(MediaType.APPLICATION_JSON).content(json);
        }
        return mvc.perform(request);
    }

    protected ResultActions getAs(TestUser user, String url) throws Exception {
        return call(get(url), user, null);
    }

    protected ResultActions postAs(TestUser user, String url, String json) throws Exception {
        return call(post(url), user, json);
    }

    protected ResultActions patchAs(TestUser user, String url, String json) throws Exception {
        return call(patch(url), user, json);
    }

    protected ResultActions putAs(TestUser user, String url, String json) throws Exception {
        return call(put(url), user, json);
    }

    protected ResultActions deleteAs(TestUser user, String url) throws Exception {
        return call(delete(url), user, null);
    }

    protected ResultActions upload(TestUser user, byte[] data, String type, String side, String contentType)
            throws Exception {
        MockMultipartFile file = new MockMultipartFile("image", "photo", contentType, data);
        var builder = multipart("/api/photos").file(file).param("type", type);
        if (side != null) {
            builder.param("side", side);
        }
        return mvc.perform(builder.header("Authorization", "Bearer " + user.token()));
    }

    protected long uploadPhoto(TestUser user, String type, String side, long seed) throws Exception {
        String body = upload(user, TestImages.jpeg(seed), type, side, "image/jpeg")
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        return ((Number) JsonPath.read(body, "$.photo_id")).longValue();
    }

    protected <T> T read(ResultActions result, String path) throws Exception {
        return JsonPath.read(result.andReturn().getResponse().getContentAsString(), path);
    }

    protected long readId(ResultActions result, String path) throws Exception {
        return ((Number) read(result, path)).longValue();
    }

    protected void advance(Duration duration) {
        clock.advance(duration);
    }

    protected long doneAnalysis(TestUser user, boolean withGoal) throws Exception {
        long photo = uploadPhoto(user, "current", "front", UUID.randomUUID().getMostSignificantBits());
        String body = withGoal
                ? "{\"photo_id\":%d,\"goal_body_id\":%d}".formatted(photo, goalId(user))
                : "{\"photo_id\":" + photo + "}";
        long id = readId(postAs(user, "/api/body-analyses/photo", body).andExpect(status().isAccepted()), "$.analysis_id");
        asyncRunner.drain();
        return id;
    }

    protected long goalId(TestUser user) throws Exception {
        var existing = getAs(user, "/api/goal-bodies");
        if (existing.andReturn().getResponse().getStatus() == 200) {
            return readId(getAs(user, "/api/goal-bodies"), "$.goal_body_id");
        }
        return readId(postAs(user, "/api/goal-bodies", "{\"description\":\"어깨가 넓은 몸\"}")
                .andExpect(status().isCreated()), "$.goal_body_id");
    }

    protected long firstExerciseId(TestUser user, String part) throws Exception {
        return readId(getAs(user, "/api/exercises?target_part=" + part).andExpect(status().isOk()), "$.items[0].exercise_id");
    }
}
