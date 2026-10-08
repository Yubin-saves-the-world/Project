package com.asdf.board.be.user.repository;

import com.asdf.board.be.user.entity.UserProfile;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserProfileRepository extends JpaRepository<UserProfile, Long> {

    boolean existsByUserId(Long userId);

    Optional<UserProfile> findFirstByUserIdOrderByIdDesc(Long userId);
}
