package com.asdf.board.be.workout.repository;

import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.global.enums.TargetPart;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ExerciseRepository extends JpaRepository<Exercise, Long> {
    Page<Exercise> findByIsActiveTrueAndTargetPartOrderByNameAsc(TargetPart targetPart, Pageable pageable);
    Page<Exercise> findByIsActiveTrueOrderByNameAsc(Pageable pageable);
}
