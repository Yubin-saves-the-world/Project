package com.asdf.board.be.auth.mail;

public interface VerificationMailSender {

    void send(String to, String code, MailPurpose purpose);
}
