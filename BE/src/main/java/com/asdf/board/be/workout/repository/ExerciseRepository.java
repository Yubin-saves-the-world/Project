package com.asdf.board.be.workout.repository;

import com.asdf.board.be.workout.entity.Exercise;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface ExerciseRepository extends JpaRepository<Exercise, Long>, JpaSpecificationExecutor<Exercise> {

    List<Exercise> findByIsActiveTrue();

    boolean existsByName(String name);

    boolean existsByNameAndIdNot(String name, Long id);
}
