package com.asdf.board.be.auth.mail;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(prefix = "vitality.mail", name = "enabled", havingValue = "true")
public class SmtpVerificationMailSender implements VerificationMailSender {

    private final JavaMailSender mailSender;
    private final MailProperties properties;

    @Override
    public void send(String to, String code, MailPurpose purpose) {
        long minutes = properties.codeTtl().toMinutes();
        String service = properties.serviceName();
        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(properties.from());
        message.setTo(to);
        switch (purpose) {
            case SIGNUP -> {
                message.setSubject("[%s] 이메일 인증번호".formatted(service));
                message.setText("""
                        %s 회원가입 인증번호는 %s 입니다.

                        %d분 안에 앱에 입력해 주세요.
                        본인이 요청하지 않았다면 이 메일을 무시해 주세요.
                        """.formatted(service, code, minutes));
            }
            case PASSWORD_RESET -> {
                message.setSubject("[%s] 비밀번호 재설정 인증번호".formatted(service));
                message.setText("""
                        %s 비밀번호 재설정 인증번호는 %s 입니다.

                        %d분 안에 앱에 입력해 주세요.
                        본인이 요청하지 않았다면 이 메일을 무시해 주세요. 비밀번호는 바뀌지 않아요.
                        """.formatted(service, code, minutes));
            }
        }
        try {
            mailSender.send(message);
        } catch (MailException e) {
            log.error("인증 메일 발송 실패: purpose={} to={}", purpose, to, e);
            throw new ApiException(ErrorCode.EMAIL_SEND_FAILED);
        }
    }
}
