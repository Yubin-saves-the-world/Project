package com.asdf.board.be.support;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.Duration;
import java.util.Locale;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

public final class EmailTokens {

    private EmailTokens() {
    }

    public static String verifiedToken(MockMvc mvc, CapturingMailSender mailSender, MutableClock clock, String rawEmail)
            throws Exception {
        String email = rawEmail.trim().toLowerCase(Locale.ROOT);
        clock.advance(Duration.ofMinutes(2));
        mvc.perform(post("/api/auth/email-verifications")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\"}".formatted(rawEmail)))
                .andExpect(status().isNoContent());
        String body = mvc.perform(post("/api/auth/email-verifications/confirm")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"code\":\"%s\"}".formatted(rawEmail, mailSender.lastCode(email))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.verification_token");
    }
}
