package com.asdf.board.be.community.dto;

import com.asdf.board.be.community.entity.Post;
import com.asdf.board.be.community.entity.PostImage;
import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record PostResponse(
        Long postId,
        String category,
        String title,
        String contentPreview,
        String content,
        AuthorDto author,
        String thumbnailUrl,
        Integer likeCount,
        Integer commentCount,
        Integer viewCount,
        Boolean isPinned,
        LocalDateTime createdAt,
        Boolean isMine,
        Boolean likedByMe,
        List<ImageDto> images
) {
    public record AuthorDto(Long userId, String nickname) {}
    public record ImageDto(Long imageId, String url) {}

    public static PostResponse ofList(Post post, Long currentUserId, String baseUrl) {
        String thumbnail = null;
        return new PostResponse(
                post.getId(),
                post.getCategory().name(),
                post.getTitle(),
                preview(post.getContent()),
                null,
                new AuthorDto(post.getUser().getId(), post.getUser().getNickname()),
                thumbnail,
                post.getLikeCount(),
                post.getCommentCount(),
                post.getViewCount(),
                post.getIsPinned(),
                post.getCreatedAt(),
                post.getUser().getId().equals(currentUserId),
                null,
                null
        );
    }

    public static PostResponse ofDetail(Post post, Long currentUserId, boolean likedByMe, List<PostImage> images, String baseUrl) {
        String thumbnail = images.isEmpty() ? null : baseUrl + "/uploads/" + images.get(0).getStorageKey();
        List<ImageDto> imageDtos = images.stream()
                .map(img -> new ImageDto(img.getId(), baseUrl + "/uploads/" + img.getStorageKey()))
                .toList();
        return new PostResponse(
                post.getId(),
                post.getCategory().name(),
                post.getTitle(),
                preview(post.getContent()),
                post.getContent(),
                new AuthorDto(post.getUser().getId(), post.getUser().getNickname()),
                thumbnail,
                post.getLikeCount(),
                post.getCommentCount(),
                post.getViewCount(),
                post.getIsPinned(),
                post.getCreatedAt(),
                post.getUser().getId().equals(currentUserId),
                likedByMe,
                imageDtos
        );
    }

    private static String preview(String content) {
        if (content == null) return "";
        return content.length() <= 100 ? content : content.substring(0, 100);
    }
}
