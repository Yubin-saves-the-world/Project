package com.asdf.board.be.global.storage;

import com.asdf.board.be.global.config.VitalityProperties;
import com.asdf.board.be.global.security.JwtProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

@Component
public class SignedUrls {

    private final String baseUrl;
    private final SecretKeySpec secretKey;
    private final Clock clock;

    public SignedUrls(VitalityProperties properties, JwtProperties jwtProperties, Clock clock) {
        this.baseUrl = properties.publicBaseUrl().replaceAll("/+$", "");
        this.secretKey = new SecretKeySpec(
                ("files:" + jwtProperties.secret()).getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        this.clock = clock;
    }

    public String url(String key, Instant expiresAt) {
        long exp = expiresAt.getEpochSecond();
        return "%s/api/files/%s?exp=%d&sig=%s".formatted(baseUrl, key, exp, sign(key, exp));
    }

    public boolean valid(String key, long exp, String signature) {
        if (signature == null || Instant.ofEpochSecond(exp).isBefore(clock.instant())) {
            return false;
        }
        return MessageDigest.isEqual(
                sign(key, exp).getBytes(StandardCharsets.UTF_8), signature.getBytes(StandardCharsets.UTF_8));
    }

    private String sign(String key, long exp) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(secretKey);
            return HexFormat.of().formatHex(mac.doFinal((key + ":" + exp).getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
