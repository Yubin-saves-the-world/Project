package com.asdf.board.be.body.integration;

import java.util.Map;

/** Refuse malformed upstream successes before marking an analysis done. */
final class AnalysisResultValidator {
  private AnalysisResultValidator() {}

  static void validate(Map<String, Object> result) {
    if (!"done".equals(result.get("status"))
        || !"pixel-dino-v1".equals(result.get("measurement_version"))
        || !(result.get("measures") instanceof Map<?, ?> measures)) {
      throw new IllegalArgumentException("Invalid AI result contract");
    }
    check(measures.get("shoulder_tilt_deg"), 90, false);
    check(measures.get("pelvis_tilt_deg"), 90, false);
    check(measures.get("shoulder_hip_ratio"), 99.99, true);
    check(measures.get("torso_leg_ratio"), 99.99, true);
  }

  private static void check(Object value, double maximum, boolean ratio) {
    if (value == null && ratio) return;
    if (!(value instanceof Number number)
        || !Double.isFinite(number.doubleValue())
        || number.doubleValue() < 0
        || (ratio && number.doubleValue() == 0)
        || number.doubleValue() > maximum) {
      throw new IllegalArgumentException("Invalid AI measurement");
    }
  }
}
