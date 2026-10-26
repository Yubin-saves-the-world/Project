package com.asdf.board.be.user.service;

import com.asdf.board.be.body.entity.Photo;
import com.asdf.board.be.community.repository.PostImageRepository;
import com.asdf.board.be.body.repository.PhotoRepository;
import com.asdf.board.be.global.storage.PhotoStorage;
import jakarta.persistence.EntityManager;
import java.util.List;
import java.util.stream.Stream;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class WithdrawalService {

    private static final List<String> DELETE_ORDER = List.of(
            "delete from routine_suggestions where user_id = :uid",
            "delete from ai_chat_messages where user_id = :uid",
            "delete from workout_logs where user_id = :uid",
            "delete from routines where user_id = :uid",
            "delete from diet_plans where user_id = :uid",
            "delete from body_analyses where user_id = :uid",
            "delete from goal_bodies where user_id = :uid",
            "delete from photos where user_id = :uid",
            "delete from post_likes where user_id = :uid",
            "delete from comments where user_id = :uid",
            "delete from posts where user_id = :uid",
            "update reports set handled_by = null where handled_by = :uid",
            "delete from reports where reporter_id = :uid",
            "delete from blocks where blocker_id = :uid or blocked_id = :uid",
            "delete from user_allergies where user_id = :uid",
            "delete from user_consents where user_id = :uid",
            "delete from user_profiles where user_id = :uid",
            "delete from user_coupons where user_id = :uid",
            "delete from user_missions where user_id = :uid",
            "delete from device_tokens where user_id = :uid",
            "delete from notification_settings where user_id = :uid",
            "delete from password_reset_tokens where user_id = :uid",
            "delete from users where user_id = :uid");

    private final EntityManager entityManager;
    private final PhotoRepository photoRepository;
    private final PhotoStorage storage;
    private final PostImageRepository postImageRepository;

    @Transactional
    public void withdraw(Long userId) {
        Stream.concat(
                        photoRepository.findByUserId(userId).stream().map(Photo::getStorageKey),
                        postImageRepository.storageKeysOfUser(userId).stream())
                .forEach(this::deleteQuietly);
        entityManager.flush();
        for (String sql : DELETE_ORDER) {
            entityManager.createNativeQuery(sql).setParameter("uid", userId).executeUpdate();
        }
        entityManager.clear();
    }

    private void deleteQuietly(String key) {
        try {
            storage.delete(key);
        } catch (RuntimeException e) {
            log.error("탈퇴 중 파일 삭제 실패 key={} (접근 불가 상태로 남음)", key, e);
        }
    }
}
