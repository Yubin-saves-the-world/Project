package com.asdf.board.be.community.repository;

import com.asdf.board.be.community.entity.Report;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReportRepository extends JpaRepository<Report, Long> {

    boolean existsByReporterIdAndTargetTypeAndTargetId(Long reporterId, Report.TargetType targetType, Long targetId);
}
