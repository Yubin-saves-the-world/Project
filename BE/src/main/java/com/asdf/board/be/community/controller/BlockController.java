package com.asdf.board.be.community.controller;

import com.asdf.board.be.community.dto.BlockedMemberResponse;
import com.asdf.board.be.community.dto.PageResult;
import com.asdf.board.be.community.service.CommunityService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@Tag(name = "community", description = "커뮤니티")
@RestController
@RequestMapping("/api/blocks")
@RequiredArgsConstructor
public class BlockController {

    private final CommunityService communityService;

    @GetMapping
    public PageResult<BlockedMemberResponse> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(name = "page_size", defaultValue = "20") int pageSize,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return communityService.getBlocks(page, pageSize, Long.valueOf(jwt.getSubject()));
    }

    @PostMapping("/{userId}")
    @ResponseStatus(HttpStatus.CREATED)
    public void block(@PathVariable Long userId, @AuthenticationPrincipal Jwt jwt) {
        communityService.block(userId, Long.valueOf(jwt.getSubject()));
    }

    @DeleteMapping("/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unblock(@PathVariable Long userId, @AuthenticationPrincipal Jwt jwt) {
        communityService.unblock(userId, Long.valueOf(jwt.getSubject()));
    }
}
