package com.asdf.board.be.body.integration;

import java.util.concurrent.*;
import org.springframework.context.annotation.*;
import org.springframework.scheduling.annotation.EnableScheduling;

@Configuration
@EnableScheduling
public class IntegrationConfig {
  @Bean(destroyMethod = "shutdown")
  public ExecutorService analysisExecutor() {
    return new ThreadPoolExecutor(
        1,
        1,
        0L,
        TimeUnit.MILLISECONDS,
        new SynchronousQueue<>(),
        new ThreadPoolExecutor.AbortPolicy());
  }
}
