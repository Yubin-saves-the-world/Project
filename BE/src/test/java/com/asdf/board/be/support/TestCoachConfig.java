package com.asdf.board.be.support;

import com.asdf.board.be.coach.ai.CoachAiClient;
import com.asdf.board.be.coach.ai.StubCoachAiClient;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

@TestConfiguration
public class TestCoachConfig {

    public static class ToggleCoachAi implements CoachAiClient {

        private final StubCoachAiClient delegate = new StubCoachAiClient();
        private volatile boolean down;

        public void setDown(boolean down) {
            this.down = down;
        }

        @Override
        public Reply ask(Context context, String question) {
            if (down) {
                throw new IllegalStateException("AI down");
            }
            return delegate.ask(context, question);
        }
    }

    @Bean
    @Primary
    public ToggleCoachAi toggleCoachAi() {
        return new ToggleCoachAi();
    }
}
