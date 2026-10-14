package com.asdf.board.be.auth.service;

import com.asdf.board.be.auth.dto.EmailVerificationTokenResponse;
import com.asdf.board.be.auth.mail.MailProperties;
import com.asdf.board.be.auth.mail.MailPurpose;
import com.asdf.board.be.auth.mail.VerificationMailSender;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.user.repository.UserRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

@Service
public class EmailVerificationService {

    private static final String TOKEN_SALT = "token";

    private final UserRepository userRepository;
    private final VerificationMailSender mailSender;
    private final MailProperties properties;
    private final Clock clock;
    private final OneTimeCodes codes;
    private final Map<String, VerifiedEmail> verified = new ConcurrentHashMap<>();

    public EmailVerificationService(
            UserRepository userRepository,
            VerificationMailSender mailSender,
            MailProperties properties,
            Clock clock) {
        this.userRepository = userRepository;
        this.mailSender = mailSender;
        this.properties = properties;
        this.clock = clock;
        this.codes = new OneTimeCodes("signup", properties, clock);
    }

    public void sendCode(String email) {
        if (userRepository.existsByEmail(email)) {
            throw new ApiException(ErrorCode.EMAIL_DUPLICATED);
        }
        synchronized (codes.lock(email)) {
            if (codes.isThrottled(email)) {
                throw new ApiException(ErrorCode.EMAIL_CODE_TOO_FREQUENT);
            }
            String code = OneTimeCodes.newCode();
            mailSender.send(email, code, MailPurpose.SIGNUP);
            codes.store(email, code);
        }
    }

    public EmailVerificationTokenResponse confirm(String email, String code) {
        synchronized (codes.lock(email)) {
            codes.verify(email, code);
            String token = OneTimeCodes.randomToken(32);
            verified.put(email, new VerifiedEmail(
                    OneTimeCodes.hash(email, token, TOKEN_SALT),
                    clock.instant().plus(properties.tokenTtl())));
            return new EmailVerificationTokenResponse(token, properties.tokenTtl().toSeconds());
        }
    }

    public void assertVerified(String email, String token) {
        VerifiedEmail entry = verified.get(email);
        if (token == null || entry == null || !clock.instant().isBefore(entry.expiresAt())
                || !MessageDigest.isEqual(
                        OneTimeCodes.hash(email, token, TOKEN_SALT).getBytes(StandardCharsets.UTF_8),
                        entry.tokenHash().getBytes(StandardCharsets.UTF_8))) {
            throw new ApiException(ErrorCode.EMAIL_NOT_VERIFIED);
        }
    }

    public void consume(String email) {
        verified.remove(email);
        codes.clear(email);
    }

    private record VerifiedEmail(String tokenHash, Instant expiresAt) {
    }
}
