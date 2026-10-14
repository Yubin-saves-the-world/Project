package com.asdf.board.be.support;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;

public class MutableClock extends Clock {

    private Instant now = Instant.now();

    public synchronized void advance(Duration duration) {
        now = now.plus(duration);
    }

    @Override
    public ZoneId getZone() {
        return ZoneId.of("Asia/Seoul");
    }

    @Override
    public Clock withZone(ZoneId zone) {
        return this;
    }

    @Override
    public synchronized Instant instant() {
        return now;
    }
}
