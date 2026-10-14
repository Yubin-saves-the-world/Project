package com.asdf.board.be.support;

import com.asdf.board.be.auth.mail.MailPurpose;
import com.asdf.board.be.auth.mail.VerificationMailSender;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class CapturingMailSender implements VerificationMailSender {

    private final Map<String, String> lastCodes = new ConcurrentHashMap<>();
    private final Map<String, Integer> sendCounts = new ConcurrentHashMap<>();
    private final Map<String, MailPurpose> lastPurposes = new ConcurrentHashMap<>();

    @Override
    public void send(String to, String code, MailPurpose purpose) {
        lastCodes.put(to, code);
        lastPurposes.put(to, purpose);
        sendCounts.merge(to, 1, Integer::sum);
    }

    public String lastCode(String email) {
        return lastCodes.get(email);
    }

    public MailPurpose lastPurpose(String email) {
        return lastPurposes.get(email);
    }

    public int sendCount(String email) {
        return sendCounts.getOrDefault(email, 0);
    }
}
