package com.asdf.board.be.community.service;

import com.asdf.board.be.community.dto.AuthorDto;
import com.asdf.board.be.community.dto.CommentDto;
import com.asdf.board.be.community.dto.CommentPageDto;
import com.asdf.board.be.community.dto.CommentRequest;
import com.asdf.board.be.community.entity.Comment;
import com.asdf.board.be.community.entity.Post;
import com.asdf.board.be.community.entity.Report;
import com.asdf.board.be.community.repository.BlockRepository;
import com.asdf.board.be.community.repository.CommentRepository;
import com.asdf.board.be.community.repository.PostRepository;
import com.asdf.board.be.community.repository.ReportRepository;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CommentService {

    static final String DELETED_TEXT = "삭제된 댓글입니다.";

    private final CommentRepository commentRepository;
    private final PostRepository postRepository;
    private final BlockRepository blockRepository;
    private final ReportRepository reportRepository;
    private final UserRepository userRepository;
    private final PostService postService;
    private final AccessGuard accessGuard;

    @Transactional(readOnly = true)
    public CommentPageDto list(Long userId, Long postId, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        postService.visiblePost(userId, postId);
        Set<Long> blocked = new HashSet<>(blockRepository.blockedIds(userId));
        List<Comment> visible = commentRepository.findAllOfPost(postId).stream()
                .filter(c -> c.getHiddenAt() == null && !blocked.contains(c.getUser().getId())).toList();

        Map<Long, List<Comment>> replies = visible.stream().filter(c -> c.getParent() != null)
                .collect(Collectors.groupingBy(c -> c.getParent().getId()));
        Set<Long> visibleIds = visible.stream().map(Comment::getId).collect(Collectors.toSet());
        List<Comment> ordered = new ArrayList<>();
        visible.stream().filter(c -> c.getParent() == null).forEach(c -> {
            ordered.add(c);
            ordered.addAll(replies.getOrDefault(c.getId(), List.of()));
        });
        visible.stream().filter(c -> c.getParent() != null && !visibleIds.contains(c.getParent().getId()))
                .forEach(ordered::add);
        return new CommentPageDto(PageParams.slice(ordered, page, pageSize).stream().map(c -> dto(c, userId)).toList(),
                page, pageSize, ordered.size());
    }

    @Transactional
    public CommentDto create(Long userId, Long postId, CommentRequest request) {
        accessGuard.requireOnboarded(userId);
        Post post = postService.visiblePost(userId, postId);
        String content = request.content().strip();
        if (content.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        Comment parent = null;
        if (request.parentId() != null) {
            parent = commentRepository.findWithUser(request.parentId())
                    .filter(c -> c.getPost().getId().equals(postId))
                    .orElseThrow(ApiException.of(ErrorCode.VALIDATION_FAILED));
            if (parent.getParent() != null) {
                parent = parent.getParent();
            }
        }
        Comment saved = commentRepository.saveAndFlush(Comment.builder()
                .post(post).user(userRepository.getReferenceById(userId)).parent(parent).content(content).build());
        syncCount(postId);
        return dto(commentRepository.findWithUser(saved.getId()).orElseThrow(), userId);
    }

    @Transactional
    public void delete(Long userId, Long postId, Long commentId) {
        accessGuard.requireOnboarded(userId);
        postService.visiblePost(userId, postId);
        Comment comment = commentRepository.findWithUser(commentId)
                .filter(c -> c.getPost().getId().equals(postId))
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (!comment.getUser().getId().equals(userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }
        Long parentId = comment.getParent() == null ? null : comment.getParent().getId();
        boolean hasReplies = commentRepository.existsByParentId(commentId);
        reportRepository.deleteOfTarget(Report.TargetType.comment, commentId);
        if (hasReplies) {
            Comment placeholder = commentRepository.findById(commentId).orElseThrow();
            placeholder.setIsDeleted(true);
            placeholder.setContent(DELETED_TEXT);
            commentRepository.flush();
        } else {
            commentRepository.deleteRow(commentId);
            if (parentId != null) {
                dropEmptyPlaceholder(parentId);
            }
        }
        syncCount(postId);
    }

    private void dropEmptyPlaceholder(Long parentId) {
        commentRepository.findById(parentId)
                .filter(p -> Boolean.TRUE.equals(p.getIsDeleted()) && commentRepository.countByParentId(parentId) == 0)
                .ifPresent(p -> commentRepository.deleteRow(parentId));
    }

    private void syncCount(Long postId) {
        postRepository.setCommentCount(postId, (int) commentRepository.countByPostIdAndIsDeletedFalse(postId));
    }

    private CommentDto dto(Comment c, Long userId) {
        boolean deleted = Boolean.TRUE.equals(c.getIsDeleted());
        return new CommentDto(c.getId(), c.getPost().getId(), c.getParent() == null ? null : c.getParent().getId(),
                new AuthorDto(c.getUser().getId(), c.getUser().getNickname()),
                deleted ? DELETED_TEXT : c.getContent(), deleted, c.getUser().getId().equals(userId),
                Times.offset(c.getCreatedAt()));
    }
}
