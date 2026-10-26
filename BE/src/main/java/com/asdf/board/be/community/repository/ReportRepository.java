package com.asdf.board.be.community.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.community.entity.Report;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ReportRepository extends JpaRepository<Report, Long> {

    boolean existsByReporterIdAndTargetTypeAndTargetId(Long reporterId, Report.TargetType type, Long targetId);

    long countByTargetTypeAndTargetIdAndStatusNot(Report.TargetType type, Long targetId, Report.Status status);

    Page<Report> findByStatus(Report.Status status, Pageable pageable);

    Page<Report> findByReporterId(Long reporterId, Pageable pageable);

    @BulkWrite
    @Query("delete from Report r where r.targetType = com.asdf.board.be.community.entity.Report$TargetType.comment and r.targetId in (select c.id from Comment c where c.post.id = :postId)")
    void deleteOfCommentsOfPost(@Param("postId") Long postId);

    @BulkWrite
    @Query("delete from Report r where r.targetType = :type and r.targetId = :targetId")
    void deleteOfTarget(@Param("type") Report.TargetType type, @Param("targetId") Long targetId);
}
