package com.asdf.board.be.community.dto;

import com.asdf.board.be.community.entity.Block;

public record BlockedMemberResponse(Long userId, String nickname) {

    public static BlockedMemberResponse from(Block block) {
        return new BlockedMemberResponse(
                block.getBlocked().getId(),
                block.getBlocked().getNickname()
        );
    }
}
