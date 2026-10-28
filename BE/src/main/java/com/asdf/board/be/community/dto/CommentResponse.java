package com.asdf.board.be.community.dto;

import com.asdf.board.be.community.entity.Comment;

public record CommentResponse(
        Long commentId,
        Long parentId,
        PostResponse.AuthorDto author,
        String content,
        Boolean isDeleted,
        Boolean isMine
) {
    public static CommentResponse of(Comment comment, Long currentUserId) {
        return new CommentResponse(
                comment.getId(),
                comment.getParent() != null ? comment.getParent().getId() : null,
                new PostResponse.AuthorDto(comment.getUser().getId(), comment.getUser().getNickname()),
                comment.getIsDeleted() ? "삭제된 댓글입니다." : comment.getContent(),
                comment.getIsDeleted(),
                comment.getUser().getId().equals(currentUserId)
        );
    }
}
