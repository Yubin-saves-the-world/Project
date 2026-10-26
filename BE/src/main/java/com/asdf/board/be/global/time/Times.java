package com.asdf.board.be.global.time;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;

public final class Times {

    public static final ZoneId KST = ZoneId.of("Asia/Seoul");

    private Times() {
    }

    public static OffsetDateTime offset(LocalDateTime value) {
        return value == null ? null : value.truncatedTo(ChronoUnit.SECONDS).atZone(KST).toOffsetDateTime();
    }

    public static OffsetDateTime offset(Instant value) {
        return value == null ? null : value.atZone(KST).toOffsetDateTime().withNano(0);
    }

    public static LocalDateTime startOfToday(Clock clock) {
        return LocalDate.now(clock).atStartOfDay();
    }

    public static OffsetDateTime nextMidnight(Clock clock) {
        return offset(LocalDate.now(clock).plusDays(1).atStartOfDay());
    }
}
