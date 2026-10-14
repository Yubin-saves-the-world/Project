package com.asdf.board.be.global.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    VALIDATION_FAILED(HttpStatus.BAD_REQUEST, "입력값을 확인해 주세요."),
    TERMS_REQUIRED(HttpStatus.BAD_REQUEST, "필수 약관에 모두 동의해 주세요."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "로그인이 필요해요."),
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않아요."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "권한이 없어요."),
    NOT_FOUND(HttpStatus.NOT_FOUND, "찾을 수 없어요."),
    EMAIL_NOT_VERIFIED(HttpStatus.BAD_REQUEST, "이메일 인증을 먼저 완료해 주세요."),
    EMAIL_CODE_INVALID(HttpStatus.BAD_REQUEST, "인증번호가 일치하지 않아요."),
    EMAIL_CODE_EXPIRED(HttpStatus.BAD_REQUEST, "인증번호가 만료됐어요. 다시 받아 주세요."),
    EMAIL_CODE_TOO_FREQUENT(HttpStatus.TOO_MANY_REQUESTS, "잠시 후에 다시 요청해 주세요."),
    EMAIL_CODE_LOCKED(HttpStatus.TOO_MANY_REQUESTS, "입력 횟수를 초과했어요. 인증번호를 다시 받아 주세요."),
    EMAIL_SEND_FAILED(HttpStatus.SERVICE_UNAVAILABLE, "인증 메일을 보내지 못했어요. 잠시 후 다시 시도해 주세요."),
    PROFILE_NOT_FOUND(HttpStatus.NOT_FOUND, "신체정보가 아직 없어요."),
    EMAIL_DUPLICATED(HttpStatus.CONFLICT, "이미 가입된 이메일이에요."),
    NICKNAME_DUPLICATED(HttpStatus.CONFLICT, "이미 사용 중인 닉네임이에요."),
    PROFILE_ALREADY_EXISTS(HttpStatus.CONFLICT, "이미 신체정보가 등록되어 있어요."),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "잠시 후 다시 시도해 주세요.");

    private final HttpStatus status;
    private final String message;
}
