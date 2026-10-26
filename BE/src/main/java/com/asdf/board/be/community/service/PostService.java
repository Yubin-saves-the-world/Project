package com.asdf.board.be.community.service;

import com.asdf.board.be.global.web.Texts;
import com.asdf.board.be.community.dto.AuthorDto;
import com.asdf.board.be.community.dto.LikeResultDto;
import com.asdf.board.be.community.dto.PostDto;
import com.asdf.board.be.community.dto.PostImageDto;
import com.asdf.board.be.community.dto.PostPageDto;
import com.asdf.board.be.community.dto.PostSummaryDto;
import com.asdf.board.be.community.entity.Post;
import com.asdf.board.be.community.entity.PostImage;
import com.asdf.board.be.community.entity.PostLike;
import com.asdf.board.be.community.entity.Report;
import com.asdf.board.be.community.repository.CommentRepository;
import com.asdf.board.be.community.repository.PostImageRepository;
import com.asdf.board.be.community.repository.PostLikeRepository;
import com.asdf.board.be.community.repository.PostRepository;
import com.asdf.board.be.community.repository.ReportRepository;
import com.asdf.board.be.global.config.VitalityProperties;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.storage.ImageFiles;
import com.asdf.board.be.global.storage.PhotoStorage;
import com.asdf.board.be.global.storage.SignedUrls;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Slf4j
@Service
@RequiredArgsConstructor
public class PostService {

    static final int MAX_IMAGES = 4;
    private static final int PREVIEW_LENGTH = 100;

    private final PostRepository postRepository;
    private final PostImageRepository imageRepository;
    private final PostLikeRepository likeRepository;
    private final CommentRepository commentRepository;
    private final ReportRepository reportRepository;
    private final UserRepository userRepository;
    private final AccessGuard accessGuard;
    private final ImageFiles imageFiles;
    private final PhotoStorage storage;
    private final SignedUrls signedUrls;
    private final VitalityProperties properties;
    private final Clock clock;

    @Transactional(readOnly = true)
    public PostPageDto list(Long userId, Post.Category category, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        var pageable = PageParams.of(page, pageSize, Sort.unsorted());
        Page<Post> result = category == null
                ? postRepository.visible(userId, pageable)
                : postRepository.visibleByCategory(userId, category, pageable);
        Map<Long, List<PostImage>> images = imagesOf(result.getContent());
        return new PostPageDto(
                result.getContent().stream().map(p -> summary(p, images.get(p.getId()))).toList(),
                page, pageSize, (int) result.getTotalElements());
    }

    @Transactional
    public PostDto create(Long userId, Post.Category category, String title, String content, List<MultipartFile> files) {
        accessGuard.requireOnboarded(userId);
        User user = userRepository.findById(userId).orElseThrow(ApiException.of(ErrorCode.UNAUTHORIZED));
        String cleanTitle = Texts.required(title, 50);
        String cleanContent = Texts.required(content, 2000);
        requireNoticeRight(category, user);
        List<ImageFiles.Image> images = readImages(files, 0);

        Post post = postRepository.save(Post.builder()
                .user(user).category(category).title(cleanTitle).content(cleanContent)
                .isPinned(category == Post.Category.notice).build());
        postRepository.flush();
        attach(post, images, 1);
        return detail(post.getId(), userId);
    }

    @Transactional
    public PostDto get(Long userId, Long postId) {
        accessGuard.requireOnboarded(userId);
        Post post = postRepository.findWithUser(postId).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        requireVisible(post, userId);
        postRepository.increaseView(postId);
        return detail(postId, userId);
    }

    @Transactional
    public PostDto patch(Long userId, Long postId, Post.Category category, String title, String content,
                         List<MultipartFile> files, List<Long> removeImageIds) {
        accessGuard.requireOnboarded(userId);
        Post post = postRepository.findWithUser(postId).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        User me = userRepository.findById(userId).orElseThrow(ApiException.of(ErrorCode.UNAUTHORIZED));
        requireVisible(post, userId);
        if (!post.getUser().getId().equals(userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }
        List<MultipartFile> nonEmpty = nonEmpty(files);
        Set<Long> remove = removeImageIds == null ? Set.of() : new HashSet<>(removeImageIds);
        if (category == null && title == null && content == null && nonEmpty.isEmpty() && remove.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        String cleanTitle = title == null ? null : Texts.required(title, 50);
        String cleanContent = content == null ? null : Texts.required(content, 2000);
        if (category != null) {
            requireNoticeRight(category, me);
        }
        List<PostImage> current = imageRepository.findByPostIdOrderByOrderNoAsc(postId);
        Set<Long> currentIds = current.stream().map(PostImage::getId).collect(Collectors.toSet());
        if (!currentIds.containsAll(remove)) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        List<ImageFiles.Image> added = readImages(nonEmpty, current.size() - remove.size());

        if (category != null) {
            post.setCategory(category);
            post.setIsPinned(category == Post.Category.notice);
        }
        if (cleanTitle != null) {
            post.setTitle(cleanTitle);
        }
        if (cleanContent != null) {
            post.setContent(cleanContent);
        }
        post.setEditedAt(LocalDateTime.now(clock));
        postRepository.flush();

        if (!remove.isEmpty()) {
            List<String> keys = current.stream().filter(i -> remove.contains(i.getId())).map(PostImage::getStorageKey).toList();
            imageRepository.deleteByIds(remove);
            keys.forEach(this::deleteFile);
        }
        List<PostImage> remaining = imageRepository.findByPostIdOrderByOrderNoAsc(postId);
        for (int i = 0; i < remaining.size(); i++) {
            if (remaining.get(i).getOrderNo() != i + 1) {
                remaining.get(i).setOrderNo(i + 1);
                imageRepository.saveAndFlush(remaining.get(i));
            }
        }
        attach(postRepository.getReferenceById(postId), added, remaining.size() + 1);
        return detail(postId, userId);
    }

    @Transactional
    public void delete(Long userId, Long postId) {
        accessGuard.requireOnboarded(userId);
        Post post = postRepository.findWithUser(postId).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (!post.getUser().getId().equals(userId) && !isAdmin(userId)) {
            throw new ApiException(ErrorCode.FORBIDDEN);
        }
        removeCompletely(postId);
    }

    @Transactional
    public void removeCompletely(Long postId) {
        List<String> keys = imageRepository.findByPostIdOrderByOrderNoAsc(postId).stream().map(PostImage::getStorageKey).toList();
        reportRepository.deleteOfCommentsOfPost(postId);
        reportRepository.deleteOfTarget(Report.TargetType.post, postId);
        likeRepository.deleteAllOfPost(postId);
        commentRepository.deleteRepliesOfPost(postId);
        commentRepository.deleteAllOfPost(postId);
        imageRepository.deleteAllOfPost(postId);
        postRepository.deleteRow(postId);
        keys.forEach(this::deleteFile);
    }

    @Transactional
    public LikeResultDto like(Long userId, Long postId) {
        accessGuard.requireOnboarded(userId);
        Post post = visiblePost(userId, postId);
        if (likeRepository.existsByIdPostIdAndIdUserId(postId, userId)) {
            throw new ApiException(ErrorCode.ALREADY_LIKED);
        }
        likeRepository.saveAndFlush(PostLike.builder()
                .post(post).user(userRepository.getReferenceById(userId)).build());
        return syncLikes(postId, true);
    }

    @Transactional
    public LikeResultDto unlike(Long userId, Long postId) {
        accessGuard.requireOnboarded(userId);
        visiblePost(userId, postId);
        likeRepository.deleteOne(postId, userId);
        return syncLikes(postId, false);
    }

    private LikeResultDto syncLikes(Long postId, boolean liked) {
        int count = likeRepository.countByIdPostId(postId);
        postRepository.setLikeCount(postId, count);
        return new LikeResultDto(postId, count, liked);
    }

    Post visiblePost(Long userId, Long postId) {
        Post post = postRepository.findWithUser(postId).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        requireVisible(post, userId);
        return post;
    }

    private void requireVisible(Post post, Long userId) {
        if (post.getHiddenAt() != null && !post.getUser().getId().equals(userId) && !isAdmin(userId)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
    }

    private boolean isAdmin(Long userId) {
        return userRepository.findById(userId).map(u -> u.getRole() == User.Role.admin).orElse(false);
    }

    private void requireNoticeRight(Post.Category category, User user) {
        if (category == Post.Category.notice && user.getRole() != User.Role.admin) {
            throw new ApiException(ErrorCode.NOTICE_ADMIN_ONLY);
        }
    }

    private static List<MultipartFile> nonEmpty(List<MultipartFile> files) {
        return files == null ? List.of() : files.stream().filter(f -> f != null && !f.isEmpty()).toList();
    }

    private List<ImageFiles.Image> readImages(List<MultipartFile> files, int existing) {
        List<MultipartFile> given = nonEmpty(files);
        if (existing + given.size() > MAX_IMAGES) {
            throw new ApiException(ErrorCode.IMAGE_LIMIT_EXCEEDED);
        }
        return given.stream().map(imageFiles::read).toList();
    }

    private void attach(Post post, List<ImageFiles.Image> images, int firstOrder) {
        int order = firstOrder;
        for (ImageFiles.Image image : images) {
            String key = "post-" + UUID.randomUUID().toString().replace("-", "") + image.extension();
            storage.put(key, image.data());
            imageRepository.save(PostImage.builder().post(post).storageKey(key).orderNo(order++).build());
        }
        imageRepository.flush();
    }

    private void deleteFile(String key) {
        try {
            storage.delete(key);
        } catch (RuntimeException e) {
            log.error("게시글 이미지 파일 삭제 실패 key={}", key, e);
        }
    }

    private PostDto detail(Long postId, Long userId) {
        Post post = postRepository.findWithUser(postId).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        List<PostImage> images = imageRepository.findByPostIdOrderByOrderNoAsc(postId);
        PostSummaryDto s = summary(post, images);
        return new PostDto(s.postId(), s.category(), s.title(), s.contentPreview(), s.author(), s.thumbnailUrl(),
                s.likeCount(), s.commentCount(), s.viewCount(), s.isPinned(), s.createdAt(),
                post.getContent(), images.stream().map(this::imageDto).toList(),
                likeRepository.existsByIdPostIdAndIdUserId(postId, userId),
                post.getUser().getId().equals(userId), Times.offset(post.getEditedAt()));
    }

    private PostSummaryDto summary(Post p, List<PostImage> images) {
        String content = p.getContent();
        String preview = content.length() <= PREVIEW_LENGTH ? content : content.substring(0, PREVIEW_LENGTH);
        String thumbnail = images == null || images.isEmpty() ? null : imageDto(images.get(0)).url();
        return new PostSummaryDto(p.getId(), p.getCategory().name(), p.getTitle(), preview,
                new AuthorDto(p.getUser().getId(), p.getUser().getNickname()), thumbnail,
                p.getLikeCount(), p.getCommentCount(), p.getViewCount(), p.getIsPinned(), Times.offset(p.getCreatedAt()));
    }

    private PostImageDto imageDto(PostImage image) {
        return new PostImageDto(image.getId(),
                signedUrls.url(image.getStorageKey(), clock.instant().plus(properties.photo().signedUrlTtl())));
    }

    private Map<Long, List<PostImage>> imagesOf(Collection<Post> posts) {
        Map<Long, List<PostImage>> result = new HashMap<>();
        if (!posts.isEmpty()) {
            imageRepository.findByPostIdInOrderByPostIdAscOrderNoAsc(posts.stream().map(Post::getId).toList())
                    .forEach(i -> result.computeIfAbsent(i.getPost().getId(), k -> new ArrayList<>()).add(i));
        }
        return result;
    }
}
