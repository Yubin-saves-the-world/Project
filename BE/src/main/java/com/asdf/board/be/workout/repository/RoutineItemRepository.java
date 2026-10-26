package com.asdf.board.be.workout.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.workout.entity.RoutineItem;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineItemRepository extends JpaRepository<RoutineItem, Long> {

    @Query("select i from RoutineItem i join fetch i.exercise where i.routine.id in :routineIds order by i.routine.id, i.orderNo")
    List<RoutineItem> findWithExercise(@Param("routineIds") Collection<Long> routineIds);

    List<RoutineItem> findByRoutineIdOrderByOrderNoAsc(Long routineId);

    @BulkWrite
    @Query("delete from RoutineItem i where i.routine.id in :ids")
    void deleteByRoutineIds(@Param("ids") Collection<Long> ids);
}
