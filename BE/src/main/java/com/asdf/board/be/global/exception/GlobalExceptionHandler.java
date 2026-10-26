package com.asdf.board.be.global.exception;

import jakarta.validation.ConstraintViolationException;
import java.util.List;
import java.util.Locale;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.multipart.MultipartException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ErrorResponse> handleApi(ApiException e) {
        return respond(e.getErrorCode());
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<ErrorResponse> handleIntegrity(DataIntegrityViolationException e) {
        String detail = String.valueOf(e.getMostSpecificCause().getMessage());
        if (detail.contains("uq_users_email")) {
            return respond(ErrorCode.EMAIL_DUPLICATED);
        }
        if (detail.contains("uq_users_nickname")) {
            return respond(ErrorCode.NICKNAME_DUPLICATED);
        }
        log.error("데이터 무결성 오류", e);
        return respond(ErrorCode.INTERNAL_ERROR);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<ErrorResponse> handleConstraint(ConstraintViolationException e) {
        List<ErrorResponse.FieldError> fields = e.getConstraintViolations().stream()
                .map(v -> {
                    String path = v.getPropertyPath().toString();
                    String name = path.substring(path.lastIndexOf('.') + 1);
                    return new ErrorResponse.FieldError(toSnakeCase(name), v.getMessage());
                })
                .toList();
        return ResponseEntity.badRequest().body(ErrorResponse.of(ErrorCode.VALIDATION_FAILED, fields));
    }

    @Override
    protected ResponseEntity<Object> handleMaxUploadSizeExceededException(
            MaxUploadSizeExceededException e, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        return ResponseEntity.status(ErrorCode.IMAGE_TOO_LARGE.getStatus()).body(ErrorResponse.of(ErrorCode.IMAGE_TOO_LARGE));
    }

    @ExceptionHandler(MultipartException.class)
    ResponseEntity<ErrorResponse> handleMultipart(MultipartException e) {
        return respond(ErrorCode.VALIDATION_FAILED);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ErrorResponse> handleUnexpected(Exception e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t.getClass().getName().endsWith("InvalidParameterException")) {
                return respond(ErrorCode.VALIDATION_FAILED);
            }
        }
        log.error("처리되지 않은 오류", e);
        return respond(ErrorCode.INTERNAL_ERROR);
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException e, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        List<ErrorResponse.FieldError> fields = e.getBindingResult().getFieldErrors().stream()
                .map(f -> new ErrorResponse.FieldError(toSnakeCase(f.getField()), f.getDefaultMessage()))
                .toList();
        return ResponseEntity.badRequest().body(ErrorResponse.of(ErrorCode.VALIDATION_FAILED, fields));
    }

    @Override
    protected ResponseEntity<Object> handleHttpMediaTypeNotSupported(
            HttpMediaTypeNotSupportedException e, HttpHeaders headers,
            HttpStatusCode status, WebRequest request) {
        ErrorCode code = request.getDescription(false).contains("/api/photos")
                ? ErrorCode.IMAGE_INVALID_TYPE : ErrorCode.VALIDATION_FAILED;
        return ResponseEntity.status(code.getStatus()).body(ErrorResponse.of(code));
    }

    @Override
    protected ResponseEntity<Object> handleHttpMessageNotReadable(
            HttpMessageNotReadableException e, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        return ResponseEntity.badRequest().body(ErrorResponse.of(ErrorCode.VALIDATION_FAILED));
    }

    @Override
    protected ResponseEntity<Object> handleExceptionInternal(
            Exception e, Object body, HttpHeaders headers, HttpStatusCode status, WebRequest request) {
        if (status.isSameCodeAs(HttpStatus.NOT_FOUND)) {
            return ResponseEntity.status(status).body(ErrorResponse.of(ErrorCode.NOT_FOUND));
        }
        if (status.isSameCodeAs(HttpStatus.BAD_REQUEST)) {
            return ResponseEntity.status(status).body(ErrorResponse.of(ErrorCode.VALIDATION_FAILED));
        }
        return super.handleExceptionInternal(e, body, headers, status, request);
    }

    private ResponseEntity<ErrorResponse> respond(ErrorCode code) {
        return ResponseEntity.status(code.getStatus()).body(ErrorResponse.of(code));
    }

    private static String toSnakeCase(String name) {
        return name.replaceAll("([a-z0-9])([A-Z])", "$1_$2").toLowerCase(Locale.ROOT);
    }
}
