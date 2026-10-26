package com.asdf.board.be.body.ai;

import com.asdf.board.be.body.dto.GoalComparisonDto;
import com.asdf.board.be.body.dto.JudgementDto;
import com.asdf.board.be.body.dto.MeasuresDto;
import java.util.List;

public interface BodyAiClient {

    GoalFeatures extractGoalFeatures(byte[] photo, String description);

    PhotoAnalysis analyze(byte[] front, byte[] side, String goalSummary, String goalDescription);

    TextSummary summarizeText(String text);

    record TextSummary(boolean ok, String summary, String errorMessage) {
    }

    record GoalFeatures(boolean ok, String summary, String errorMessage) {
    }

    record PhotoAnalysis(
            boolean ok,
            String errorCode,
            String errorMessage,
            MeasuresDto measures,
            Integer balanceScore,
            String bodyType,
            String measurementVersion,
            List<JudgementDto> judgements,
            GoalComparisonDto comparison) {
    }
}
