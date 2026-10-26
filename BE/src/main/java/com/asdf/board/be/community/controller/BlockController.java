package com.asdf.board.be.community.controller;

import com.asdf.board.be.community.dto.BlockPageDto;
import com.asdf.board.be.community.dto.BlockedUserDto;
import com.asdf.board.be.community.service.BlockService;
import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "community", description = "커뮤니티")
@Validated
@RestController
@RequestMapping("/api/blocks")
@RequiredArgsConstructor
public class BlockController {

    private final BlockService blockService;

    @Operation(summary = "사용자 차단", description = "차단한 사용자의 글·댓글은 내 화면에서 보이지 않습니다. 상대에게는 알리지 않습니다.")
    @PostMapping("/{blockedUserId}")
    @ResponseStatus(HttpStatus.CREATED)
    public BlockedUserDto block(@AuthenticationPrincipal Jwt jwt, @PathVariable("blockedUserId") Long blockedUserId) {
        return blockService.block(CurrentUser.id(jwt), blockedUserId);
    }

    @Operation(summary = "차단 해제", description = "존재하지 않는 사용자면 NOT_FOUND. 차단하지 않은 사용자면 에러 없이 204.")
    @DeleteMapping("/{blockedUserId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unblock(@AuthenticationPrincipal Jwt jwt, @PathVariable("blockedUserId") Long blockedUserId) {
        blockService.unblock(CurrentUser.id(jwt), blockedUserId);
    }

    @Operation(summary = "차단 목록")
    @GetMapping
    public BlockPageDto list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return blockService.list(CurrentUser.id(jwt), page, pageSize);
    }
}
