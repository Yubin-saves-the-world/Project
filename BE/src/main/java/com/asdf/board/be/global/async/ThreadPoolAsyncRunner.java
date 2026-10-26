package com.asdf.board.be.global.async;

import jakarta.annotation.PreDestroy;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Slf4j
@Component
public class ThreadPoolAsyncRunner implements AsyncRunner {

    private final ExecutorService pool = Executors.newFixedThreadPool(4, runnable -> {
        Thread thread = new Thread(runnable, "vitality-async");
        thread.setDaemon(true);
        return thread;
    });

    @Override
    public void run(Runnable task) {
        Runnable safe = () -> {
            try {
                task.run();
            } catch (RuntimeException e) {
                log.error("비동기 작업 실패", e);
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    pool.execute(safe);
                }
            });
        } else {
            pool.execute(safe);
        }
    }

    @PreDestroy
    void shutdown() {
        pool.shutdown();
    }
}
