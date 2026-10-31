package com.asdf.board.be.body.integration;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.*;
import org.junit.jupiter.api.Test;

class AnalysisExplanationTest {
  @Test
  void explainsSmallPhotoAnglesWithoutClinicalVerdict() {
    var result =
        AnalysisExplanation.describe(
            Map.of(
                "shoulder_tilt_deg",
                .4,
                "pelvis_tilt_deg",
                1.18,
                "shoulder_hip_ratio",
                1.72,
                "torso_leg_ratio",
                .7));
    assertThat((List<?>) result.get("observations")).hasSize(4);
    assertThat(result.get("summary").toString()).contains("수평에 가깝게").contains("판정한 결과는 아닙니다");
  }

  @Test
  void doesNotInventMissingOrInvalidMeasurements() {
    var result = AnalysisExplanation.describe(Map.of("shoulder_tilt_deg", Double.NaN));
    assertThat((List<?>) result.get("observations")).isEmpty();
    assertThat(result.get("summary").toString()).contains("얻지 못했습니다");
  }

  @Test
  void largerPhotoAngleSuggestsRecaptureRatherThanDisease() {
    var result = AnalysisExplanation.describe(Map.of("shoulder_tilt_deg", 7.2));
    assertThat(result.toString()).contains("촬영 자세 재확인").doesNotContain("질환입니다");
  }
}
