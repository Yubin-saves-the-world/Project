package com.asdf.board.be.community.dto;

public record LikeResultDto(Long postId, Integer likeCount, Boolean likedByMe) {
}
