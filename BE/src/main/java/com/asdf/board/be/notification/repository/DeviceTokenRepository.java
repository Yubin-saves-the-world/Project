package com.asdf.board.be.notification.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.notification.entity.DeviceToken;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, Long> {

    Optional<DeviceToken> findByUserIdAndPlatform(Long userId, DeviceToken.Platform platform);

    @BulkWrite
    @Query("delete from DeviceToken d where d.tokenHash = :hash")
    void deleteByHash(@Param("hash") String hash);
}
