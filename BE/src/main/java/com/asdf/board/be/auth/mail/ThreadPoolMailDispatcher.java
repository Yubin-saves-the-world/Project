package com.asdf.board.be.auth.mail;

import jakarta.annotation.PreDestroy;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.springframework.stereotype.Component;

@Component
public class ThreadPoolMailDispatcher implements MailDispatcher {

    private final ExecutorService pool = Executors.newFixedThreadPool(2, runnable -> {
        Thread thread = new Thread(runnable, "mail-dispatcher");
        thread.setDaemon(true);
        return thread;
    });

    @Override
    public void dispatch(Runnable task) {
        pool.execute(task);
    }

    @PreDestroy
    void shutdown() {
        pool.shutdown();
    }
}
