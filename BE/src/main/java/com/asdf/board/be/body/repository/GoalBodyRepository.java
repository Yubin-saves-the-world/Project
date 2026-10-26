package com.asdf.board.be.body.repository;

import com.asdf.board.be.body.entity.GoalBody;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GoalBodyRepository extends JpaRepository<GoalBody, Long> {

    Optional<GoalBody> findFirstByUserIdOrderByIdDesc(Long userId);

    Optional<GoalBody> findByIdAndUserId(Long id, Long userId);

    boolean existsByUserId(Long userId);

    boolean existsBySourcePhotoIdAndStatus(Long photoId, GoalBody.Status status);

    List<GoalBody> findByStatusAndCreatedAtBefore(GoalBody.Status status, LocalDateTime time);
}
