package com.asdf.board.be.workout.repository;

import com.asdf.board.be.workout.entity.Routine;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface RoutineRepository extends JpaRepository<Routine, Long> {

    Optional<Routine> findByUserIdAndScheduledDate(Long userId, LocalDate date);

    @Query("SELECT r FROM Routine r WHERE r.user.id = :userId AND r.scheduledDate BETWEEN :start AND :end ORDER BY r.scheduledDate ASC")
    List<Routine> findByUserIdAndDateRange(@Param("userId") Long userId, @Param("start") LocalDate start, @Param("end") LocalDate end);
}
