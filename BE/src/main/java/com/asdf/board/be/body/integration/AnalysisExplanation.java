package com.asdf.board.be.body.integration;

import java.util.*;

/** Descriptive photo geometry, not a diagnosis or learned muscle classification. */
public final class AnalysisExplanation {
  private AnalysisExplanation() {}

  public static Map<String, Object> describe(Map<?, ?> measures) {
    List<Map<String, Object>> observations = new ArrayList<>();
    angle(observations, measures, "shoulder_tilt_deg", "어깨선", "좌우 어깨 추정점");
    angle(observations, measures, "pelvis_tilt_deg", "골반 연결선", "좌우 골반 추정점");
    Double shoulderHip = number(measures.get("shoulder_hip_ratio"));
    if (shoulderHip != null) {
      observations.add(
          note(
              "shoulder_hip_ratio",
              "어깨·골반 너비",
              "관절 간 너비 비교",
              String.format(
                  Locale.ROOT,
                  "사진에서 어깨 관절 사이의 거리는 골반 관절 사이 거리의 약 %.2f배입니다. 옷 바깥선이나 근육량을 비교한 값은 아닙니다.",
                  shoulderHip)));
    }
    Double torsoLeg = number(measures.get("torso_leg_ratio"));
    if (torsoLeg != null) {
      observations.add(
          note(
              "torso_leg_ratio",
              "상체·하체 길이",
              "사진상 길이 비교",
              String.format(
                  Locale.ROOT,
                  "어깨 중심부터 골반 중심까지의 길이는 골반 중심부터 발목 중심까지 길이의 약 %.2f배입니다. 카메라 높이와 원근에 영향을 받으며 실제 신체"
                      + " 치수는 아닙니다.",
                  torsoLeg)));
    }
    String summary;
    if (observations.isEmpty()) {
      summary = "이번 사진에서 해석할 수 있는 수치를 얻지 못했습니다. 전신이 잘 보이는 사진으로 다시 확인해 주세요.";
    } else {
      Double shoulder = number(measures.get("shoulder_tilt_deg"));
      Double pelvis = number(measures.get("pelvis_tilt_deg"));
      if (shoulder != null
          && pelvis != null
          && Math.abs(shoulder) <= 2.5
          && Math.abs(pelvis) <= 2.5) {
        summary = "이번 사진에서는 어깨선과 골반 연결선이 수평에 가깝게 측정됐습니다. 실제 자세의 정상 여부나 근육 발달을 판정한 결과는 아닙니다.";
      } else {
        summary =
            "이번 사진의 관절 위치를 기준으로 어깨·골반 연결선과 신체 비율을 확인했습니다. 기울기가 보이는 항목은 카메라와 서 있는 자세를 맞춰 재촬영한 결과와"
                + " 비교해 주세요.";
      }
    }
    return BodyIntegrationService.obj(
        "summary",
        summary,
        "observations",
        observations,
        "next_steps",
        List.of(
            "카메라를 기울이지 않고 같은 높이·거리에서 다시 촬영해 수치가 반복되는지 확인해 보세요.",
            "근육 윤곽은 의복·조명·포즈의 영향을 받습니다. 현재 모델은 특징만 추출하므로 근육 부족 부위나 발달 등급은 결정하지 않습니다."),
        "interpretation_method",
        "photo-geometry-rules-v1",
        "interpretation_note",
        "수평과의 차이 2.5° 이하·5° 이하를 설명용으로 구분한 임시 기준입니다. 임상적으로 검증된 정상·이상 기준이 아니며 개인에게 필요한 운동을 결정하지"
            + " 않습니다.");
  }

  private static Map<String, Object> note(String key, String title, String label, String text) {
    return BodyIntegrationService.obj(
        "key", key, "title", title, "label", label, "description", text);
  }

  private static void angle(
      List<Map<String, Object>> notes,
      Map<?, ?> measures,
      String key,
      String title,
      String points) {
    Double raw = number(measures.get(key));
    if (raw == null) return;
    double value = Math.abs(raw);
    String label = value <= 2.5 ? "사진상 수평에 가까움" : value <= 5 ? "사진상 기울기 관찰" : "촬영 자세 재확인";
    String detail =
        String.format(Locale.ROOT, "%s을 연결한 선이 사진의 수평선과 약 %.2f° 차이 납니다. ", points, value);
    detail +=
        value <= 2.5 ? "이 사진에서 연결선의 기울기는 작게 나타났습니다." : "카메라가 기울었거나 한쪽에 체중을 실었을 때도 이 차이가 생길 수 있습니다.";
    detail += " 관절 추정과 촬영 조건에 영향을 받으므로 실제 골격 상태를 단정할 수 없습니다.";
    notes.add(note(key, title, label, detail));
  }

  private static Double number(Object value) {
    if (!(value instanceof Number n) || !Double.isFinite(n.doubleValue())) return null;
    return n.doubleValue();
  }
}
