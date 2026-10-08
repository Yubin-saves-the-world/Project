package com.asdf.board.be.global.exception;

import java.util.List;

public record ErrorResponse(String code, String message, int status, List<FieldError> fields) {

    public record FieldError(String field, String reason) {
    }

    public static ErrorResponse of(ErrorCode errorCode) {
        return new ErrorResponse(errorCode.name(), errorCode.getMessage(), errorCode.getStatus().value(), null);
    }

    public static ErrorResponse of(ErrorCode errorCode, List<FieldError> fields) {
        return new ErrorResponse(errorCode.name(), errorCode.getMessage(), errorCode.getStatus().value(), fields);
    }
}
