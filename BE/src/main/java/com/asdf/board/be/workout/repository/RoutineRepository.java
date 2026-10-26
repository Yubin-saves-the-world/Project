package com.asdf.board.be.workout.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.workout.entity.Routine;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineRepository extends JpaRepository<Routine, Long> {

    Optional<Routine> findByIdAndUserId(Long id, Long userId);

    Optional<Routine> findByUserIdAndScheduledDate(Long userId, LocalDate date);

    List<Routine> findByUserIdAndScheduledDateBetween(Long userId, LocalDate from, LocalDate to);

    @BulkWrite
    @Query("delete from Routine r where r.id in :ids")
    void deleteByIds(@Param("ids") Collection<Long> ids);

    List<Routine> findByUserIdAndScheduledDateGreaterThanEqualAndStatus(
            Long userId, LocalDate from, Routine.Status status);
}
