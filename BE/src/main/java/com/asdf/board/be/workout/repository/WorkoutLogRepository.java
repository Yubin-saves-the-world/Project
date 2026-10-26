package com.asdf.board.be.workout.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.workout.entity.WorkoutLog;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, Long> {

    Optional<WorkoutLog> findByIdAndUserId(Long id, Long userId);

    Optional<WorkoutLog> findByUserIdAndExerciseIdAndStatus(Long userId, Long exerciseId, WorkoutLog.Status status);

    List<WorkoutLog> findByRoutineIdAndStatus(Long routineId, WorkoutLog.Status status);

    List<WorkoutLog> findByRoutineIdInAndStatus(Collection<Long> routineIds, WorkoutLog.Status status);

    @EntityGraph(attributePaths = "exercise")
    Page<WorkoutLog> findByUserIdAndWorkoutDateBetween(Long userId, LocalDate from, LocalDate to, Pageable pageable);

    @EntityGraph(attributePaths = "exercise")
    Page<WorkoutLog> findByUserIdAndWorkoutDateBetweenAndStatus(
            Long userId, LocalDate from, LocalDate to, WorkoutLog.Status status, Pageable pageable);

    @EntityGraph(attributePaths = "exercise")
    List<WorkoutLog> findByUserIdAndWorkoutDateBetweenAndStatus(
            Long userId, LocalDate from, LocalDate to, WorkoutLog.Status status);

    List<WorkoutLog> findByUserIdAndStatusAndCompletedAtBetween(
            Long userId, WorkoutLog.Status status, LocalDateTime from, LocalDateTime to);

    long countByUserIdAndWorkoutDateBetweenAndStatus(Long userId, LocalDate from, LocalDate to, WorkoutLog.Status status);

    List<WorkoutLog> findByStatusAndStartedAtBefore(WorkoutLog.Status status, LocalDateTime time);

    @Query("select distinct l.workoutDate from WorkoutLog l where l.user.id = :userId and l.status = com.asdf.board.be.workout.entity.WorkoutLog$Status.completed order by l.workoutDate desc")
    List<LocalDate> completedDates(@Param("userId") Long userId);

    @BulkWrite
    @Query("delete from WorkoutLog l where l.id = :id")
    void deleteRow(@Param("id") Long id);
}
