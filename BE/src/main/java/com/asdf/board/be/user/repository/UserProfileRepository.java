package com.asdf.board.be.user.repository;

import com.asdf.board.be.user.entity.UserProfile;
import java.util.Collection;
import java.util.Optional;
import java.util.Set;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserProfileRepository extends JpaRepository<UserProfile, Long> {

    boolean existsByUserId(Long userId);

    Optional<UserProfile> findFirstByUserIdOrderByIdDesc(Long userId);

    @Query("select distinct p.user.id from UserProfile p where p.user.id in :ids")
    Set<Long> userIdsWithProfile(@Param("ids") Collection<Long> ids);

    Page<UserProfile> findByUserId(Long userId, Pageable pageable);
}
