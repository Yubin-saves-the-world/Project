package com.asdf.board.be.support;

import com.asdf.board.be.auth.mail.MailDispatcher;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

@TestConfiguration
public class TestMailConfig {

    @Bean
    @Primary
    CapturingMailSender capturingMailSender() {
        return new CapturingMailSender();
    }

    @Bean
    @Primary
    MutableClock mutableClock() {
        return new MutableClock();
    }

    @Bean
    @Primary
    MailDispatcher inlineMailDispatcher() {
        return Runnable::run;
    }
}
