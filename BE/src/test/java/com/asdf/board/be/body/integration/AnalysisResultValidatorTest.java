package com.asdf.board.be.body.integration;

import static org.assertj.core.api.Assertions.*;

import java.util.*;
import org.junit.jupiter.api.Test;

class AnalysisResultValidatorTest {
  private Map<String, Object> response() {
    return new HashMap<>(
        Map.of(
            "status",
            "done",
            "measurement_version",
            "pixel-dino-v1",
            "measures",
            new HashMap<>(
                Map.of(
                    "shoulder_tilt_deg",
                    .4,
                    "pelvis_tilt_deg",
                    1.18,
                    "shoulder_hip_ratio",
                    1.72,
                    "torso_leg_ratio",
                    .7))));
  }

  @Test
  void acceptsRealContractAndUnavailableRatios() {
    var result = response();
    assertThatCode(() -> AnalysisResultValidator.validate(result)).doesNotThrowAnyException();
    ((Map<?, ?>) result.get("measures")).clear();
    result.put("measures", Map.of("shoulder_tilt_deg", .4, "pelvis_tilt_deg", 1.18));
    assertThatCode(() -> AnalysisResultValidator.validate(result)).doesNotThrowAnyException();
  }

  @Test
  void rejectsWrongStatusVersionAndMissingMeasures() {
    for (var entry :
        Map.of("status", "failed", "measurement_version", "unknown", "measures", "invalid")
            .entrySet()) {
      var result = response();
      result.put(entry.getKey(), entry.getValue());
      assertThatIllegalArgumentException()
          .isThrownBy(() -> AnalysisResultValidator.validate(result));
    }
  }

  @Test
  void rejectsNonfiniteNegativeAndOutOfColumnRangeValues() {
    for (double value : new double[] {Double.NaN, Double.POSITIVE_INFINITY, -1, 100}) {
      var result = response();
      result.put("measures", Map.of("shoulder_tilt_deg", value, "pelvis_tilt_deg", .5));
      assertThatIllegalArgumentException()
          .isThrownBy(() -> AnalysisResultValidator.validate(result));
    }
  }

  @Test
  void rejectsZeroRatiosAndNonNumericMeasurements() {
    for (Object value : List.of(0, "1.7", 1000)) {
      var result = response();
      result.put(
          "measures",
          Map.of("shoulder_tilt_deg", .4, "pelvis_tilt_deg", .5, "shoulder_hip_ratio", value));
      assertThatIllegalArgumentException()
          .isThrownBy(() -> AnalysisResultValidator.validate(result));
    }
  }
}
