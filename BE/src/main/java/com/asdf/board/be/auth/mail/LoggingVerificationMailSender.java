package com.asdf.board.be.auth.mail;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@ConditionalOnProperty(prefix = "vitality.mail", name = "enabled", havingValue = "false", matchIfMissing = true)
public class LoggingVerificationMailSender implements VerificationMailSender {

    @Override
    public void send(String to, String code, MailPurpose purpose) {
        log.warn("[개발용] 메일 발송이 꺼져 있어 인증번호를 로그로만 남깁니다. purpose={} to={} code={}", purpose, to, code);
    }
}
