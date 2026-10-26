package com.asdf.board.be.support;

import com.asdf.board.be.global.async.AsyncRunner;
import java.util.ArrayDeque;
import java.util.Deque;

public class QueueAsyncRunner implements AsyncRunner {

    private final Deque<Runnable> queue = new ArrayDeque<>();

    @Override
    public synchronized void run(Runnable task) {
        queue.add(task);
    }

    public synchronized int pending() {
        return queue.size();
    }

    public void drain() {
        Runnable task;
        while ((task = poll()) != null) {
            task.run();
        }
    }

    private synchronized Runnable poll() {
        return queue.poll();
    }
}
