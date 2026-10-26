package com.asdf.board.be.community.controller;

import com.asdf.board.be.community.dto.CommentDto;
import com.asdf.board.be.community.dto.CommentPageDto;
import com.asdf.board.be.community.dto.CommentRequest;
import com.asdf.board.be.community.dto.LikeResultDto;
import com.asdf.board.be.community.dto.PostDto;
import com.asdf.board.be.community.dto.PostPageDto;
import com.asdf.board.be.community.entity.Post;
import com.asdf.board.be.community.service.CommentService;
import com.asdf.board.be.community.service.PostService;
import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "community", description = "커뮤니티")
@Validated
@RestController
@RequestMapping("/api/posts")
@RequiredArgsConstructor
public class PostController {

    private final PostService postService;
    private final CommentService commentService;

    @Operation(summary = "게시글 목록", description = "고정글이 맨 위, 나머지는 최신순. 차단한 사용자의 글과 신고 누적으로 숨겨진 글은 제외합니다.")
    @GetMapping
    public PostPageDto list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "category", required = false) Post.Category category,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return postService.list(CurrentUser.id(jwt), category, page, pageSize);
    }

    @Operation(summary = "게시글 작성", description = "multipart/form-data. notice는 관리자만. 이미지는 최대 4장(JPG·PNG, 각 10MB).")
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PostDto create(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam("category") Post.Category category,
            @RequestParam("title") String title,
            @RequestParam("content") String content,
            @RequestParam(value = "images", required = false) List<MultipartFile> images) {
        return postService.create(CurrentUser.id(jwt), category, title, content, images);
    }

    @Operation(summary = "게시글 조회", description = "조회할 때마다 view_count를 1 올립니다.")
    @GetMapping("/{postId}")
    public PostDto get(@AuthenticationPrincipal Jwt jwt, @PathVariable("postId") Long postId) {
        return postService.get(CurrentUser.id(jwt), postId);
    }

    @Operation(summary = "게시글 수정", description = "본인 글만. 보낸 필드만 바꿉니다. 수정 후 이미지가 4장을 넘으면 IMAGE_LIMIT_EXCEEDED.")
    @PatchMapping(value = "/{postId}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public PostDto patch(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("postId") Long postId,
            @RequestParam(value = "category", required = false) Post.Category category,
            @RequestParam(value = "title", required = false) String title,
            @RequestParam(value = "content", required = false) String content,
            @RequestParam(value = "images", required = false) List<MultipartFile> images,
            @RequestParam(value = "remove_image_ids", required = false) List<Long> removeImageIds) {
        return postService.patch(CurrentUser.id(jwt), postId, category, title, content, images, removeImageIds);
    }

    @Operation(summary = "게시글 삭제", description = "본인 글만(관리자는 다른 사용자의 글도). 댓글·좋아요·이미지도 함께 삭제합니다.")
    @DeleteMapping("/{postId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable("postId") Long postId) {
        postService.delete(CurrentUser.id(jwt), postId);
    }

    @Operation(summary = "댓글 목록", description = "오래된 순. 대댓글은 부모 바로 뒤. 차단한 사용자의 댓글은 제외합니다.")
    @GetMapping("/{postId}/comments")
    public CommentPageDto comments(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("postId") Long postId,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return commentService.list(CurrentUser.id(jwt), postId, page, pageSize);
    }

    @Operation(summary = "댓글 작성", description = "parent_id가 있으면 같은 게시글의 댓글이어야 합니다. 댓글의 댓글까지만, 그 이상 깊이는 부모의 부모로 붙입니다.")
    @PostMapping("/{postId}/comments")
    @ResponseStatus(HttpStatus.CREATED)
    public CommentDto createComment(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("postId") Long postId, @Valid @RequestBody CommentRequest request) {
        return commentService.create(CurrentUser.id(jwt), postId, request);
    }

    @Operation(summary = "댓글 삭제", description = "본인 댓글만. 대댓글이 있으면 자리를 남기고(is_deleted=true) 없으면 완전히 삭제합니다.")
    @DeleteMapping("/{postId}/comments/{commentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteComment(
            @AuthenticationPrincipal Jwt jwt, @PathVariable("postId") Long postId, @PathVariable("commentId") Long commentId) {
        commentService.delete(CurrentUser.id(jwt), postId, commentId);
    }

    @Operation(summary = "게시글 좋아요")
    @PostMapping("/{postId}/likes")
    public LikeResultDto like(@AuthenticationPrincipal Jwt jwt, @PathVariable("postId") Long postId) {
        return postService.like(CurrentUser.id(jwt), postId);
    }

    @Operation(summary = "게시글 좋아요 취소", description = "좋아요를 안 한 상태에서 호출해도 에러 없이 현재 상태를 반환합니다.")
    @DeleteMapping("/{postId}/likes")
    public LikeResultDto unlike(@AuthenticationPrincipal Jwt jwt, @PathVariable("postId") Long postId) {
        return postService.unlike(CurrentUser.id(jwt), postId);
    }
}
