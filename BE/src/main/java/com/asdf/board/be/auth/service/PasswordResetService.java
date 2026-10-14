package com.asdf.board.be.auth.service;

import com.asdf.board.be.auth.dto.PasswordResetTokenResponse;
import com.asdf.board.be.auth.mail.MailDispatcher;
import com.asdf.board.be.auth.mail.MailProperties;
import com.asdf.board.be.auth.mail.MailPurpose;
import com.asdf.board.be.auth.mail.VerificationMailSender;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.user.entity.PasswordResetToken;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.PasswordResetTokenRepository;
import com.asdf.board.be.user.repository.UserRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
public class PasswordResetService {

    private static final Duration TOKEN_TTL = Duration.ofMinutes(30);

    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final VerificationMailSender mailSender;
    private final MailDispatcher dispatcher;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;
    private final OneTimeCodes codes;

    public PasswordResetService(
            UserRepository userRepository,
            PasswordResetTokenRepository tokenRepository,
            VerificationMailSender mailSender,
            MailDispatcher dispatcher,
            PasswordEncoder passwordEncoder,
            MailProperties properties,
            Clock clock) {
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
        this.mailSender = mailSender;
        this.dispatcher = dispatcher;
        this.passwordEncoder = passwordEncoder;
        this.clock = clock;
        this.codes = new OneTimeCodes("password-reset", properties, clock);
    }

    public void requestReset(String email) {
        synchronized (codes.lock(email)) {
            if (codes.isThrottled(email)) {
                return;
            }
            boolean eligible = userRepository.findByEmail(email).filter(this::canResetPassword).isPresent();
            if (!eligible) {
                codes.recordSend(email);
                return;
            }
            String code = OneTimeCodes.newCode();
            codes.store(email, code);
            dispatcher.dispatch(() -> {
                try {
                    mailSender.send(email, code, MailPurpose.PASSWORD_RESET);
                } catch (RuntimeException e) {
                    log.warn("비밀번호 재설정 메일 발송에 실패했어요.", e);
                }
            });
        }
    }

    @Transactional
    public PasswordResetTokenResponse verifyCode(String email, String code) {
        synchronized (codes.lock(email)) {
            codes.verify(email, code);
            User user = userRepository.findByEmail(email)
                    .filter(this::canResetPassword)
                    .orElseThrow(() -> new ApiException(ErrorCode.EMAIL_CODE_EXPIRED));
            LocalDateTime now = LocalDateTime.now(clock);
            closeOpenTokens(user, now);
            String token = OneTimeCodes.randomToken(32);
            tokenRepository.save(PasswordResetToken.builder()
                    .user(user)
                    .tokenHash(OneTimeCodes.sha256(token))
                    .expiresAt(now.plus(TOKEN_TTL))
                    .build());
            return new PasswordResetTokenResponse(token, TOKEN_TTL.toSeconds());
        }
    }

    @Transactional
    public void reset(String token, String newPassword) {
        LocalDateTime now = LocalDateTime.now(clock);
        PasswordResetToken entry = tokenRepository.findByTokenHashForUpdate(OneTimeCodes.sha256(token))
                .filter(found -> found.getUsedAt() == null && found.getExpiresAt().isAfter(now))
                .orElseThrow(() -> new ApiException(ErrorCode.RESET_TOKEN_INVALID));
        User user = entry.getUser();
        if (!canResetPassword(user)) {
            throw new ApiException(ErrorCode.RESET_TOKEN_INVALID);
        }
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        entry.setUsedAt(now);
        closeOpenTokens(user, now);
    }

    private void closeOpenTokens(User user, LocalDateTime now) {
        tokenRepository.findByUserAndUsedAtIsNull(user).forEach(open -> open.setUsedAt(now));
    }

    private boolean canResetPassword(User user) {
        return user.getStatus() == User.Status.active
                && user.getAuthProvider() == User.AuthProvider.email
                && user.getPasswordHash() != null;
    }
}
