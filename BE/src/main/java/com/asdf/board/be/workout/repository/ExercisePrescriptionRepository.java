package com.asdf.board.be.workout.repository;

import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.workout.entity.ExercisePrescription;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ExercisePrescriptionRepository extends JpaRepository<ExercisePrescription, ExercisePrescription.Key> {

    List<ExercisePrescription> findByIdExerciseId(Long exerciseId);

    List<ExercisePrescription> findByIdExerciseIdInAndIdExperienceLevel(
            Collection<Long> exerciseIds, ExperienceLevel experienceLevel);
}
