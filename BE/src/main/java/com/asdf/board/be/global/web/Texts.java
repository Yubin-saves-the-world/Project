package com.asdf.board.be.global.web;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import java.util.regex.Pattern;

public final class Texts {

    private static final Pattern WHITESPACE = Pattern.compile("\\s+");

    private Texts() {
    }

    public static String required(String value, int max) {
        if (value == null || value.isBlank() || value.strip().length() > max) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        return value.strip();
    }

    public static String compact(String value) {
        return WHITESPACE.matcher(value).replaceAll("");
    }

    public static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.strip();
    }
}
