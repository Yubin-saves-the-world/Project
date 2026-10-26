package com.asdf.board.be.correction.service;

import com.asdf.board.be.body.dto.JudgementDto;
import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.body.repository.BodyAnalysisRepository;
import com.asdf.board.be.correction.dto.CorrectionExerciseDetailDto;
import com.asdf.board.be.correction.dto.CorrectionExerciseDto;
import com.asdf.board.be.correction.dto.CorrectionListDto;
import com.asdf.board.be.correction.entity.CorrectionExercise;
import com.asdf.board.be.correction.repository.CorrectionExerciseRepository;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.user.service.AccessGuard;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.EnumSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

@Service
@RequiredArgsConstructor
public class CorrectionService {

    private static final int PER_ISSUE = 3;

    private final CorrectionExerciseRepository corrections;
    private final BodyAnalysisRepository analyses;
    private final AccessGuard accessGuard;
    private final JsonMapper jsonMapper;

    @Transactional(readOnly = true)
    public CorrectionListDto list(Long userId, CorrectionExercise.TargetIssue targetIssue) {
        accessGuard.requireOnboarded(userId);
        BodyAnalysis latest = analyses
                .findFirstByUserIdAndStatusAndSourceOrderByIdDesc(userId, BodyAnalysis.Status.done, BodyAnalysis.Source.photo)
                .orElse(null);
        Long analysisId = latest == null ? null : latest.getId();
        Set<CorrectionExercise.TargetIssue> issues = EnumSet.noneOf(CorrectionExercise.TargetIssue.class);
        if (targetIssue != null) {
            issues.add(targetIssue);
        } else if (latest != null && latest.getJudgementsJson() != null) {
            for (JudgementDto j : jsonMapper.readValue(latest.getJudgementsJson(), new TypeReference<List<JudgementDto>>() { })) {
                if ("caution".equals(j.level())) {
                    issueOf(j.item()).ifPresent(issues::add);
                }
            }
        }
        List<CorrectionExerciseDto> items = new ArrayList<>();
        for (CorrectionExercise.TargetIssue issue : issues) {
            corrections.findByTargetIssueAndIsActiveTrueOrderByIdAsc(issue).stream().limit(PER_ISSUE)
                    .forEach(c -> items.add(summary(c)));
        }
        return new CorrectionListDto(analysisId, items);
    }

    @Transactional(readOnly = true)
    public CorrectionExerciseDetailDto get(Long userId, Long id) {
        accessGuard.requireOnboarded(userId);
        CorrectionExercise c = corrections.findByIdAndIsActiveTrue(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        return detail(c);
    }

    public static CorrectionExerciseDetailDto detail(CorrectionExercise c) {
        return new CorrectionExerciseDetailDto(
                c.getId(), c.getTargetIssue().name(), c.getName(), c.getDurationOrReps(), c.getMediaUrl(), c.getMethod());
    }

    private static Optional<CorrectionExercise.TargetIssue> issueOf(String item) {
        return Arrays.stream(CorrectionExercise.TargetIssue.values()).filter(i -> i.name().equals(item)).findFirst();
    }

    private static CorrectionExerciseDto summary(CorrectionExercise c) {
        return new CorrectionExerciseDto(c.getId(), c.getTargetIssue().name(), c.getName(), c.getDurationOrReps(), c.getMediaUrl());
    }
}
