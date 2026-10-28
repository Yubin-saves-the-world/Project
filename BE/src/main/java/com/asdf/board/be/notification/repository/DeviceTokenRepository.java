package com.asdf.board.be.notification.repository;

import com.asdf.board.be.notification.entity.DeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {
    Optional<DeviceToken> findByUserIdAndPlatform(Long userId, DeviceToken.Platform platform);
    void deleteByUserIdAndPlatform(Long userId, DeviceToken.Platform platform);
}
