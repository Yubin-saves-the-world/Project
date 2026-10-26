package com.asdf.board.be.global.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

@ConfigurationProperties(prefix = "vitality")
public record VitalityProperties(
        @DefaultValue("http://localhost:8080") String publicBaseUrl,
        @DefaultValue Storage storage,
        @DefaultValue Photo photo,
        @DefaultValue Analysis analysis,
        @DefaultValue Ai ai
) {

    public record Storage(@DefaultValue("./storage") String dir) {
    }

    public record Photo(
            @DefaultValue("10485760") long maxBytes,
            @DefaultValue("20") int maxPerUser,
            @DefaultValue("1h") Duration signedUrlTtl,
            @DefaultValue("1h") Duration goalPhotoTtl
    ) {
    }

    public record Analysis(
            @DefaultValue("3") int dailyLimit,
            @DefaultValue("90s") Duration timeout,
            @DefaultValue("2000") int pollAfterMs
    ) {
    }

    public record Ai(
            @DefaultValue("stub") String mode,
            @DefaultValue("") String baseUrl,
            @DefaultValue("30") int coachDailyLimit,
            @DefaultValue("10s") Duration stubDelay
    ) {
    }
}
