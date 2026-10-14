package com.asdf.board.be.auth.mail;

import java.time.Clock;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(MailProperties.class)
public class MailConfig {

    @Bean
    Clock clock() {
        return Clock.systemDefaultZone();
    }
}
