package com.asdf.board.be.community.controller;

import com.asdf.board.be.community.dto.ReportDto;
import com.asdf.board.be.community.dto.ReportPageDto;
import com.asdf.board.be.community.dto.ReportRequest;
import com.asdf.board.be.community.service.ReportService;
import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "community", description = "커뮤니티")
@Validated
@RestController
@RequestMapping("/api/reports")
@RequiredArgsConstructor
public class ReportController {

    private final ReportService reportService;

    @Operation(summary = "게시글·댓글 신고", description = "서로 다른 신고자 3명이 신고하면 대상을 자동으로 숨깁니다. 자기 글·댓글은 신고할 수 없습니다.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ReportDto create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ReportRequest request) {
        return reportService.create(CurrentUser.id(jwt), request);
    }

    @Operation(summary = "내 신고 내역")
    @GetMapping
    public ReportPageDto mine(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return reportService.mine(CurrentUser.id(jwt), page, pageSize);
    }
}
