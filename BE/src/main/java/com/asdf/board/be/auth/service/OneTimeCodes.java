package com.asdf.board.be.auth.service;

import com.asdf.board.be.auth.mail.MailProperties;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Base64;
import java.util.Deque;
import java.util.HexFormat;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

final class OneTimeCodes {

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Duration SEND_HISTORY_WINDOW = Duration.ofHours(1);

    private final String namespace;
    private final MailProperties properties;
    private final Clock clock;
    private final Map<String, Pending> pending = new ConcurrentHashMap<>();
    private final Map<String, Deque<Instant>> sendHistory = new ConcurrentHashMap<>();

    OneTimeCodes(String namespace, MailProperties properties, Clock clock) {
        this.namespace = namespace;
        this.properties = properties;
        this.clock = clock;
    }

    Object lock(String key) {
        return (namespace + ":" + key).intern();
    }

    boolean isThrottled(String key) {
        Instant now = clock.instant();
        Deque<Instant> history = sendHistory.computeIfAbsent(key, k -> new ArrayDeque<>());
        while (!history.isEmpty() && history.peekFirst().isBefore(now.minus(SEND_HISTORY_WINDOW))) {
            history.pollFirst();
        }
        boolean tooSoon = !history.isEmpty()
                && now.isBefore(history.peekLast().plus(properties.resendInterval()));
        return tooSoon || history.size() >= properties.hourlyLimit();
    }

    void recordSend(String key) {
        sendHistory.computeIfAbsent(key, k -> new ArrayDeque<>()).addLast(clock.instant());
    }

    void store(String key, String code) {
        Instant now = clock.instant();
        String salt = randomToken(8);
        pending.put(key, new Pending(salt, hash(key, code, salt), now.plus(properties.codeTtl()), 0));
        recordSend(key);
    }

    void verify(String key, String code) {
        Instant now = clock.instant();
        Pending current = pending.get(key);
        if (current == null || !now.isBefore(current.expiresAt())) {
            pending.remove(key);
            throw new ApiException(ErrorCode.EMAIL_CODE_EXPIRED);
        }
        if (current.attempts() >= properties.maxAttempts()) {
            pending.remove(key);
            throw new ApiException(ErrorCode.EMAIL_CODE_LOCKED);
        }
        boolean matches = MessageDigest.isEqual(
                hash(key, code, current.salt()).getBytes(StandardCharsets.UTF_8),
                current.hash().getBytes(StandardCharsets.UTF_8));
        if (!matches) {
            int attempts = current.attempts() + 1;
            if (attempts >= properties.maxAttempts()) {
                pending.remove(key);
                throw new ApiException(ErrorCode.EMAIL_CODE_LOCKED);
            }
            pending.put(key, current.withAttempts(attempts));
            throw new ApiException(ErrorCode.EMAIL_CODE_INVALID);
        }
        pending.remove(key);
    }

    void clear(String key) {
        pending.remove(key);
    }

    static String newCode() {
        return "%06d".formatted(RANDOM.nextInt(1_000_000));
    }

    static String randomToken(int bytes) {
        byte[] buffer = new byte[bytes];
        RANDOM.nextBytes(buffer);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(buffer);
    }

    static String hash(String key, String secret, String salt) {
        return sha256(salt + ":" + key + ":" + secret);
    }

    static String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private record Pending(String salt, String hash, Instant expiresAt, int attempts) {
        Pending withAttempts(int value) {
            return new Pending(salt, hash, expiresAt, value);
        }
    }
}
