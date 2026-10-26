package com.asdf.board.be.workout.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.workout.entity.WorkoutSet;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WorkoutSetRepository extends JpaRepository<WorkoutSet, Long> {

    List<WorkoutSet> findByLogIdOrderBySetNoAsc(Long logId);

    List<WorkoutSet> findByLogIdIn(Collection<Long> logIds);

    List<WorkoutSet> findByLogIdInAndIsDoneTrue(Collection<Long> logIds);

    Optional<WorkoutSet> findByLogIdAndClientSetId(Long logId, String clientSetId);

    boolean existsByLogIdAndSetNo(Long logId, Integer setNo);

    Optional<WorkoutSet> findByIdAndLogId(Long id, Long logId);

    @BulkWrite
    @Query("delete from WorkoutSet s where s.log.id = :logId")
    void deleteByLogId(@Param("logId") Long logId);
}
