package com.asdf.board.be.body.integration;

import com.asdf.board.be.body.entity.BodyAnalysis;
import jakarta.persistence.LockModeType;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

public interface AnalysisRepository extends JpaRepository<BodyAnalysis, Long> {
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Override
  Optional<BodyAnalysis> findById(Long id);

  List<BodyAnalysis> findByUserIdOrderByIdDesc(Long userId);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  List<BodyAnalysis> findByStatus(BodyAnalysis.Status status);
}
