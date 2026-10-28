package com.asdf.board.be.body.repository;

import com.asdf.board.be.body.entity.GoalBody;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface GoalBodyRepository extends JpaRepository<GoalBody, Long> {
    Optional<GoalBody> findTopByUserIdOrderByCreatedAtDesc(Long userId);
}
