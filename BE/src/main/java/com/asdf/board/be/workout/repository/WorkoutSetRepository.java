package com.asdf.board.be.workout.repository;

import com.asdf.board.be.workout.entity.WorkoutSet;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface WorkoutSetRepository extends JpaRepository<WorkoutSet, Long> {
    List<WorkoutSet> findByLogIdOrderBySetNoAsc(Long logId);
    Optional<WorkoutSet> findByLogIdAndId(Long logId, Long setId);
    int countByLogId(Long logId);
}
