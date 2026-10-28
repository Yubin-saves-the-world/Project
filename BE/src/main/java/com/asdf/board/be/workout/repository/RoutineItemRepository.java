package com.asdf.board.be.workout.repository;

import com.asdf.board.be.workout.entity.RoutineItem;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RoutineItemRepository extends JpaRepository<RoutineItem, Long> {
    List<RoutineItem> findByRoutineIdOrderByOrderNoAsc(Long routineId);
}
