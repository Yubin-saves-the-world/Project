package com.asdf.board.be.body.ai;

import com.asdf.board.be.body.dto.BodyPartDto;
import com.asdf.board.be.body.dto.GoalComparisonDto;
import com.asdf.board.be.body.dto.JudgementDto;
import com.asdf.board.be.body.dto.MeasureUnavailableDto;
import com.asdf.board.be.body.dto.MeasuresDto;
import com.asdf.board.be.global.config.VitalityProperties;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * AI 서버가 연결되기 전까지 쓰는 개발용 구현. 사진 내용을 분석하지 않고 사진 바이트의 해시에서 값을 만든다.
 * measurementVersion이 stub-v0이므로 앱·QA는 실제 측정값과 구분할 수 있다.
 */
@Slf4j
@Component
public class StubBodyAiClient implements BodyAiClient {

    public static final String VERSION = "stub-v0";
    private static final int MIN_BYTES = 1024;
    private static final String[][] PARTS = {
            {"shoulder", "어깨"}, {"back", "등"}, {"chest", "가슴"}, {"arm", "팔"}, {"core", "복근"}, {"leg", "하체"}};
    private static final String[] GOAL_STYLES = {
            "어깨가 넓고 허리가 잘록한 역삼각형 체형", "등과 가슴이 두껍고 팔이 발달한 체형", "하체가 탄탄하고 코어가 선명한 체형"};

    private final VitalityProperties properties;

    public StubBodyAiClient(VitalityProperties properties) {
        this.properties = properties;
        if (!"stub".equals(properties.ai().mode())) {
            throw new IllegalStateException("vitality.ai.mode=" + properties.ai().mode() + " 구현은 아직 없습니다. stub만 지원합니다.");
        }
        log.warn("[개발용] AI 서버 대신 StubBodyAiClient를 사용합니다. 분석 수치는 실제 측정값이 아닙니다.");
    }

    @Override
    public GoalFeatures extractGoalFeatures(byte[] photo, String description) {
        pause();
        if (photo == null) {
            return new GoalFeatures(true, null, null);
        }
        if (photo.length < MIN_BYTES) {
            return new GoalFeatures(false, null, "사진에서 체형을 찾지 못했어요. 다른 사진으로 다시 시도해 주세요.");
        }
        int[] h = digest(photo);
        String summary = "(개발용) " + GOAL_STYLES[h[0] % GOAL_STYLES.length];
        if (description != null && !description.isBlank()) {
            summary += " · 설명: " + description.trim();
        }
        return new GoalFeatures(true, truncate(summary, 480), null);
    }

    @Override
    public PhotoAnalysis analyze(byte[] front, byte[] side, String goalSummary, String goalDescription) {
        pause();
        if (front == null || front.length < MIN_BYTES) {
            return new PhotoAnalysis(false, "NO_PERSON", "전신이 보이는 사진으로 다시 촬영해 주세요.",
                    null, null, null, null, List.of(), null);
        }
        int[] h = digest(front);
        BigDecimal shoulder = scaled(0.3 + (h[0] % 40) / 10.0, 1);
        BigDecimal pelvis = scaled(0.2 + (h[1] % 30) / 10.0, 1);
        BigDecimal neck = side == null ? null : scaled(5 + h[2] % 20, 1);
        BigDecimal shoulderHip = scaled(1.2 + (h[3] % 40) / 100.0, 2);
        BigDecimal torsoLeg = scaled(0.8 + (h[4] % 30) / 100.0, 2);

        List<MeasureUnavailableDto> unavailable = new ArrayList<>();
        if (neck == null) {
            unavailable.add(new MeasureUnavailableDto("neck_forward", "SIDE_PHOTO_MISSING"));
        }
        MeasuresDto measures = new MeasuresDto(shoulder, pelvis, neck, shoulderHip, torsoLeg, unavailable);
        List<JudgementDto> judgements = List.of(
                judgement("shoulder_tilt", "어깨 기울기", shoulder, 2.0),
                judgement("pelvis_tilt", "골반 기울기", pelvis, 2.0),
                judgement("neck_forward", "목 전방 기울기", neck, 15.0));

        GoalComparisonDto comparison = null;
        if (goalSummary != null || goalDescription != null) {
            int a = h[5] % PARTS.length;
            int b = (a + 1 + h[6] % (PARTS.length - 1)) % PARTS.length;
            List<BodyPartDto> parts = List.of(new BodyPartDto(PARTS[a][0], PARTS[a][1]), new BodyPartDto(PARTS[b][0], PARTS[b][1]));
            comparison = new GoalComparisonDto(parts,
                    "목표 대비 %s·%s 발달이 가장 필요해요".formatted(PARTS[a][1], PARTS[b][1]),
                    "개발용 스텁 결과입니다. 실제 AI가 연결되면 현재 사진과 목표 체형 특징을 비교한 소견이 들어갑니다.");
        }
        return new PhotoAnalysis(true, null, null, measures, null, null, VERSION, judgements, comparison);
    }

    @Override
    public TextSummary summarizeText(String text) {
        pause();
        if (text == null || text.isBlank()) {
            return new TextSummary(false, null, "체형을 설명하는 글이 필요해요.");
        }
        return new TextSummary(true, truncate("(개발용) 입력하신 설명을 바탕으로 한 요약입니다: " + text.strip(), 480), null);
    }

    private static JudgementDto judgement(String item, String label, BigDecimal value, double limit) {
        if (value == null) {
            return new JudgementDto(item, label, null, "deg", "unavailable", "SIDE_PHOTO_MISSING");
        }
        return new JudgementDto(item, label, value, "deg", value.doubleValue() > limit ? "caution" : "good", null);
    }

    private static BigDecimal scaled(double value, int scale) {
        return BigDecimal.valueOf(value).setScale(scale, RoundingMode.HALF_UP);
    }

    private static int[] digest(byte[] data) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(data);
            int[] out = new int[hash.length];
            for (int i = 0; i < hash.length; i++) {
                out[i] = hash[i] & 0xFF;
            }
            return out;
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private void pause() {
        long millis = properties.ai().stubDelay().toMillis();
        if (millis > 0) {
            try {
                Thread.sleep(millis);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    private static String truncate(String value, int max) {
        return value.length() <= max ? value : value.substring(0, max);
    }
}
