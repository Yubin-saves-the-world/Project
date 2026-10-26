package com.asdf.board.be.support;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

@TestConfiguration
public class TestAsyncConfig {

    @Bean
    @Primary
    QueueAsyncRunner queueAsyncRunner() {
        return new QueueAsyncRunner();
    }
}
