package com.asdf.board.be.auth.mail;

public interface MailDispatcher {

    void dispatch(Runnable task);
}
