package com.asdf.board.be.body.service;

import com.asdf.board.be.global.storage.ImageFiles;
import com.asdf.board.be.body.dto.DeletedCountDto;
import com.asdf.board.be.body.dto.PhotoDto;
import com.asdf.board.be.body.dto.PhotoPageDto;
import com.asdf.board.be.body.entity.GoalBody;
import com.asdf.board.be.body.entity.Photo;
import com.asdf.board.be.body.repository.GoalBodyRepository;
import com.asdf.board.be.body.repository.PhotoRepository;
import com.asdf.board.be.global.config.VitalityProperties;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.storage.PhotoStorage;
import com.asdf.board.be.global.storage.SignedUrls;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class PhotoService {

    private final PhotoRepository photoRepository;
    private final GoalBodyRepository goalBodyRepository;
    private final UserRepository userRepository;
    private final PhotoStorage storage;
    private final ImageFiles imageFiles;
    private final SignedUrls signedUrls;
    private final AccessGuard accessGuard;
    private final VitalityProperties properties;
    private final Clock clock;

    @Transactional
    public PhotoDto upload(Long userId, MultipartFile image, Photo.Type type, Photo.Side side) {
        accessGuard.requireOnboarded(userId);
        accessGuard.requireConsent(userId, UserConsent.ConsentType.body_photo);
        ImageFiles.Image file = imageFiles.read(image);
        if (photoRepository.countByUserId(userId) >= properties.photo().maxPerUser()) {
            throw new ApiException(ErrorCode.PHOTO_LIMIT_EXCEEDED);
        }
        User user = userRepository.getReferenceById(userId);
        String key = UUID.randomUUID().toString().replace("-", "") + file.extension();
        storage.put(key, file.data());
        LocalDateTime now = LocalDateTime.now(clock);
        Photo photo = photoRepository.save(Photo.builder()
                .user(user)
                .type(type)
                .side(side == null ? Photo.Side.front : side)
                .storageKey(key)
                .contentType(file.contentType())
                .sizeBytes(file.data().length)
                .expiresAt(type == Photo.Type.goal ? now.plus(properties.photo().goalPhotoTtl()) : null)
                .build());
        photoRepository.flush();
        return toDto(photo);
    }

    @Transactional(readOnly = true)
    public PhotoPageDto list(Long userId, Photo.Type type, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        var pageable = PageParams.of(page, pageSize, Sort.by(Sort.Direction.DESC, "id"));
        Page<Photo> result = type == null
                ? photoRepository.findByUserId(userId, pageable)
                : photoRepository.findByUserIdAndType(userId, type, pageable);
        List<PhotoDto> items = result.getContent().stream().map(this::toDto).toList();
        return new PhotoPageDto(items, page, pageSize, (int) result.getTotalElements());
    }

    @Transactional
    public void delete(Long userId, Long photoId) {
        accessGuard.requireOnboarded(userId);
        Photo photo = photoRepository.findByIdAndUserId(photoId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (inUse(photo)) {
            throw new ApiException(ErrorCode.PHOTO_IN_USE);
        }
        remove(photo);
    }

    @Transactional
    public DeletedCountDto deleteAll(Long userId, Photo.Type type) {
        accessGuard.requireOnboarded(userId);
        int deleted = 0;
        int skipped = 0;
        for (Photo photo : photoRepository.findByUserIdAndType(userId, type)) {
            if (inUse(photo)) {
                skipped++;
            } else {
                remove(photo);
                deleted++;
            }
        }
        return new DeletedCountDto(deleted, skipped);
    }

    @Transactional
    public int removeExpiredGoalPhotos() {
        List<Photo> expired = photoRepository.findByTypeAndExpiresAtBefore(Photo.Type.goal, LocalDateTime.now(clock));
        int removed = 0;
        for (Photo photo : expired) {
            if (!inUse(photo)) {
                remove(photo);
                removed++;
            }
        }
        return removed;
    }

    private boolean inUse(Photo photo) {
        return photo.getType() == Photo.Type.goal
                && goalBodyRepository.existsBySourcePhotoIdAndStatus(photo.getId(), GoalBody.Status.pending);
    }

    private void remove(Photo photo) {
        storage.delete(photo.getStorageKey());
        photoRepository.deleteRow(photo.getId());
    }

    private PhotoDto toDto(Photo photo) {
        Instant expires = clock.instant().plus(properties.photo().signedUrlTtl());
        return new PhotoDto(
                photo.getId(),
                photo.getType().name(),
                photo.getSide().name(),
                signedUrls.url(photo.getStorageKey(), expires),
                Times.offset(expires),
                Times.offset(photo.getCreatedAt()));
    }

}
