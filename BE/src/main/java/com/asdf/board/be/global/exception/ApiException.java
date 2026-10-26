package com.asdf.board.be.global.exception;

import java.util.function.Supplier;
import lombok.Getter;

@Getter
public class ApiException extends RuntimeException {

    private final ErrorCode errorCode;

    public ApiException(ErrorCode errorCode) {
        super(errorCode.getMessage());
        this.errorCode = errorCode;
    }

    public static Supplier<ApiException> of(ErrorCode errorCode) {
        return () -> new ApiException(errorCode);
    }
}
