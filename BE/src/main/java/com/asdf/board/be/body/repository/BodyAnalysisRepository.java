package com.asdf.board.be.body.repository;

import com.asdf.board.be.body.entity.BodyAnalysis;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BodyAnalysisRepository extends JpaRepository<BodyAnalysis, Long> {

    Optional<BodyAnalysis> findByIdAndUserId(Long id, Long userId);

    Page<BodyAnalysis> findByUserId(Long userId, Pageable pageable);

    boolean existsByUserIdAndStatus(Long userId, BodyAnalysis.Status status);

    long countByUserIdAndStatusInAndCreatedAtGreaterThanEqual(
            Long userId, Collection<BodyAnalysis.Status> statuses, LocalDateTime since);

    List<BodyAnalysis> findByStatusAndCreatedAtBefore(BodyAnalysis.Status status, LocalDateTime time);

    Optional<BodyAnalysis> findFirstByUserIdAndStatusOrderByIdDesc(Long userId, BodyAnalysis.Status status);

    Optional<BodyAnalysis> findFirstByUserIdAndStatusAndSourceOrderByIdDesc(
            Long userId, BodyAnalysis.Status status, BodyAnalysis.Source source);
}
