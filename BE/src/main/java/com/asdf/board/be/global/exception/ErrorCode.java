package com.asdf.board.be.global.exception;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    VALIDATION_FAILED(HttpStatus.BAD_REQUEST, "입력값을 확인해 주세요."),
    TERMS_REQUIRED(HttpStatus.BAD_REQUEST, "필수 약관에 모두 동의해 주세요."),
    EMAIL_NOT_VERIFIED(HttpStatus.BAD_REQUEST, "이메일 인증을 먼저 완료해 주세요."),
    EMAIL_CODE_INVALID(HttpStatus.BAD_REQUEST, "인증번호가 일치하지 않아요."),
    EMAIL_CODE_EXPIRED(HttpStatus.BAD_REQUEST, "인증번호가 만료됐어요. 다시 받아 주세요."),
    RESET_TOKEN_INVALID(HttpStatus.BAD_REQUEST, "비밀번호 재설정이 만료되었거나 올바르지 않아요. 처음부터 다시 진행해 주세요."),
    PHOTO_TYPE_MISMATCH(HttpStatus.BAD_REQUEST, "사진 종류가 맞지 않아요."),
    WORKOUT_EMPTY(HttpStatus.BAD_REQUEST, "완료한 세트가 없어요."),
    IMAGE_LIMIT_EXCEEDED(HttpStatus.BAD_REQUEST, "이미지는 최대 4장까지 올릴 수 있어요."),
    CANNOT_BLOCK_SELF(HttpStatus.BAD_REQUEST, "자기 자신은 차단할 수 없어요."),
    OAUTH_FAILED(HttpStatus.UNAUTHORIZED, "소셜 로그인에 실패했어요. 다시 시도해 주세요."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "로그인이 필요해요."),
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않아요."),
    CONSENT_REQUIRED(HttpStatus.FORBIDDEN, "사진·AI 분석 동의가 필요해요. 설정에서 동의하면 이어서 쓸 수 있어요."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "권한이 없어요."),
    ONBOARDING_REQUIRED(HttpStatus.FORBIDDEN, "먼저 신체정보를 입력해 주세요."),
    NOTICE_ADMIN_ONLY(HttpStatus.FORBIDDEN, "공지는 운영팀만 작성할 수 있어요."),
    NOT_FOUND(HttpStatus.NOT_FOUND, "찾을 수 없어요."),
    PROFILE_NOT_FOUND(HttpStatus.NOT_FOUND, "신체정보가 아직 없어요."),
    GOAL_NOT_FOUND(HttpStatus.NOT_FOUND, "등록된 목표 체형이 없어요."),
    DIET_NOT_FOUND(HttpStatus.NOT_FOUND, "해당 날짜의 식단이 없어요."),
    NO_ACTIVE_MISSION(HttpStatus.NOT_FOUND, "진행 중인 미션이 없어요."),
    EMAIL_DUPLICATED(HttpStatus.CONFLICT, "이미 가입된 이메일이에요."),
    NICKNAME_DUPLICATED(HttpStatus.CONFLICT, "이미 사용 중인 닉네임이에요."),
    PROFILE_ALREADY_EXISTS(HttpStatus.CONFLICT, "이미 신체정보가 등록되어 있어요."),
    GOAL_ALREADY_EXISTS(HttpStatus.CONFLICT, "이미 목표 체형이 있어요."),
    ALLERGY_DUPLICATED(HttpStatus.CONFLICT, "이미 등록된 항목이에요."),
    PHOTO_LIMIT_EXCEEDED(HttpStatus.CONFLICT, "저장할 수 있는 사진 수를 넘었어요. 기존 사진을 삭제해 주세요."),
    PHOTO_IN_USE(HttpStatus.CONFLICT, "목표 체형을 분석하는 중인 사진이에요. 잠시 후 다시 시도해 주세요."),
    ANALYSIS_IN_PROGRESS(HttpStatus.CONFLICT, "분석이 진행 중이에요. 잠시만 기다려 주세요."),
    ANALYSIS_NOT_READY(HttpStatus.CONFLICT, "분석이 완료된 뒤에 사용할 수 있어요."),
    GOAL_NOT_READY(HttpStatus.CONFLICT, "목표 체형 분석이 아직 끝나지 않았어요."),
    WORKOUT_ALREADY_COMPLETED(HttpStatus.CONFLICT, "이미 끝난 운동이에요."),
    SET_DUPLICATED(HttpStatus.CONFLICT, "같은 번호의 세트가 이미 있어요."),
    VERSION_CONFLICT(HttpStatus.CONFLICT, "다른 곳에서 먼저 수정했어요. 새로고침해 주세요."),
    SUGGESTION_ALREADY_HANDLED(HttpStatus.CONFLICT, "이미 처리된 제안이에요."),
    SUGGESTION_EXPIRED(HttpStatus.CONFLICT, "제안이 만료되었어요."),
    ALREADY_LIKED(HttpStatus.CONFLICT, "이미 좋아요를 눌렀어요."),
    ALREADY_REPORTED(HttpStatus.CONFLICT, "이미 신고한 내용이에요."),
    ALREADY_BLOCKED(HttpStatus.CONFLICT, "이미 차단한 사용자예요."),
    IMAGE_TOO_LARGE(HttpStatus.PAYLOAD_TOO_LARGE, "사진은 10MB 이하만 올릴 수 있어요."),
    IMAGE_INVALID_TYPE(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "JPG 또는 PNG 사진만 올릴 수 있어요."),
    EMAIL_CODE_TOO_FREQUENT(HttpStatus.TOO_MANY_REQUESTS, "잠시 후에 다시 요청해 주세요."),
    EMAIL_CODE_LOCKED(HttpStatus.TOO_MANY_REQUESTS, "입력 횟수를 초과했어요. 인증번호를 다시 받아 주세요."),
    ANALYSIS_QUOTA_EXCEEDED(HttpStatus.TOO_MANY_REQUESTS, "오늘 분석 횟수를 모두 사용했어요."),
    AI_QUOTA_EXCEEDED(HttpStatus.TOO_MANY_REQUESTS, "오늘 AI 코치 질문 횟수를 모두 사용했어요."),
    INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "잠시 후 다시 시도해 주세요."),
    AI_UNAVAILABLE(HttpStatus.BAD_GATEWAY, "AI 코치가 잠시 어려워요. 다시 시도해 주세요."),
    EMAIL_SEND_FAILED(HttpStatus.SERVICE_UNAVAILABLE, "인증 메일을 보내지 못했어요. 잠시 후 다시 시도해 주세요.");

    private final HttpStatus status;
    private final String message;
}
