package com.asdf.board.be.community.controller;

import com.asdf.board.be.community.dto.ReportRequest;
import com.asdf.board.be.community.service.CommunityService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@Tag(name = "community", description = "커뮤니티")
@RestController
@RequestMapping("/api/reports")
@RequiredArgsConstructor
public class ReportController {

    private final CommunityService communityService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public void report(@RequestBody ReportRequest req, @AuthenticationPrincipal Jwt jwt) {
        communityService.report(req, Long.valueOf(jwt.getSubject()));
    }
}
