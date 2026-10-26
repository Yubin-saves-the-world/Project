package com.asdf.board.be.correction.repository;

import com.asdf.board.be.correction.entity.CorrectionExercise;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CorrectionExerciseRepository extends JpaRepository<CorrectionExercise, Long> {

    List<CorrectionExercise> findByTargetIssueAndIsActiveTrueOrderByIdAsc(CorrectionExercise.TargetIssue targetIssue);

    Optional<CorrectionExercise> findByIdAndIsActiveTrue(Long id);
}
