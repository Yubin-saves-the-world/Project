package com.asdf.board.be.community.service;

import com.asdf.board.be.global.web.Texts;
import com.asdf.board.be.community.dto.ReportDto;
import com.asdf.board.be.community.dto.ReportPageDto;
import com.asdf.board.be.community.dto.ReportRequest;
import com.asdf.board.be.community.entity.Report;
import com.asdf.board.be.community.repository.CommentRepository;
import com.asdf.board.be.community.repository.PostRepository;
import com.asdf.board.be.community.repository.ReportRepository;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import java.time.Clock;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ReportService {

    static final int HIDE_THRESHOLD = 3;

    private final ReportRepository reportRepository;
    private final PostRepository postRepository;
    private final CommentRepository commentRepository;
    private final UserRepository userRepository;
    private final AccessGuard accessGuard;
    private final Clock clock;

    @Transactional
    public ReportDto create(Long userId, ReportRequest request) {
        accessGuard.requireOnboarded(userId);
        Long authorId = switch (request.targetType()) {
            case post -> postRepository.findById(request.targetId()).map(p -> p.getUser().getId())
                    .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
            case comment -> commentRepository.findById(request.targetId()).map(c -> c.getUser().getId())
                    .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        };
        if (authorId.equals(userId)) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        if (reportRepository.existsByReporterIdAndTargetTypeAndTargetId(userId, request.targetType(), request.targetId())) {
            throw new ApiException(ErrorCode.ALREADY_REPORTED);
        }
        String detail = Texts.blankToNull(request.detail());
        Report saved = reportRepository.saveAndFlush(Report.builder()
                .reporter(userRepository.getReferenceById(userId)).targetType(request.targetType())
                .targetId(request.targetId()).reason(request.reason()).detail(detail).build());
        if (reportRepository.countByTargetTypeAndTargetIdAndStatusNot(
                request.targetType(), request.targetId(), Report.Status.rejected) >= HIDE_THRESHOLD) {
            LocalDateTime now = LocalDateTime.now(clock);
            switch (request.targetType()) {
                case post -> postRepository.hide(request.targetId(), now);
                case comment -> commentRepository.hide(request.targetId(), now);
            }
        }
        return dto(reportRepository.findById(saved.getId()).orElseThrow());
    }

    @Transactional(readOnly = true)
    public ReportPageDto mine(Long userId, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        Page<Report> result = reportRepository.findByReporterId(
                userId, PageParams.of(page, pageSize, Sort.by(Sort.Direction.DESC, "id")));
        return new ReportPageDto(result.getContent().stream().map(ReportService::dto).toList(),
                page, pageSize, (int) result.getTotalElements());
    }

    static ReportDto dto(Report r) {
        return new ReportDto(r.getId(), r.getTargetType().name(), r.getTargetId(), r.getReason().name(),
                r.getDetail(), r.getStatus().name(), Times.offset(r.getCreatedAt()));
    }
}
