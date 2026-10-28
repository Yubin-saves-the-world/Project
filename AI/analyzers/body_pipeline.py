from __future__ import annotations

import math
import os
import sys
import contextlib
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any

from .analyze_body import analyze_image
from schemas.analysis_result import (
    BodyAnalysisResponse,
    BodyShapeResult,
    MetricJudgement,
    PostureResult,
    PriorityPart,
)


def _valid(values: list[float | None]) -> list[float]:
    return [float(value) for value in values if value is not None]


@contextlib.contextmanager
def quiet_mediapipe_logs():
    try:
        stderr_fd = sys.stderr.fileno()
        saved_fd = os.dup(stderr_fd)
        with open(os.devnull, "w") as devnull:
            os.dup2(devnull.fileno(), stderr_fd)
            try:
                yield
            finally:
                os.dup2(saved_fd, stderr_fd)
                os.close(saved_fd)
    except Exception:
        yield


def _mean(values: list[float | None]) -> float | None:
    usable = _valid(values)
    if not usable:
        return None
    return sum(usable) / len(usable)


def _std(values: list[float | None]) -> float | None:
    usable = _valid(values)
    if len(usable) < 2:
        return 0.0 if usable else None
    avg = sum(usable) / len(usable)
    return math.sqrt(sum((value - avg) ** 2 for value in usable) / (len(usable) - 1))


def _min(values: list[float | None]) -> float | None:
    usable = _valid(values)
    return min(usable) if usable else None


def _max(values: list[float | None]) -> float | None:
    usable = _valid(values)
    return max(usable) if usable else None


def _round(value: float | None, digits: int = 2) -> float | None:
    if value is None:
        return None
    return round(float(value), digits)


def _metric_summary(analyses: list[dict[str, Any]], key: str, absolute: bool = False) -> dict[str, Any]:
    values = [item["metrics"].get(key) for item in analyses]
    if absolute:
        values = [abs(value) if value is not None else None for value in values]
    return {
        "mean": _round(_mean(values), 4),
        "std": _round(_std(values), 4),
        "min": _round(_min(values), 4),
        "max": _round(_max(values), 4),
    }


def _balance_score(analyses: list[dict[str, Any]]) -> int | None:
    symmetry = _mean([item["metrics"].get("skeletal_symmetry_score") for item in analyses])
    if symmetry is None:
        return None
    return max(0, min(100, round(symmetry * 100)))


def _body_type(metrics: dict[str, Any]) -> str:
    shoulder_hip = metrics.get("shoulder_to_hip_ratio")
    waist_chest = metrics.get("waist_to_chest_ratio")
    waist_hip = metrics.get("waist_to_hip_ratio")
    abdomen_chest = metrics.get("abdomen_to_chest_ratio")
    thigh_waist = metrics.get("thigh_to_waist_ratio")

    scores = Counter()
    if shoulder_hip is not None:
        if shoulder_hip >= 1.25:
            scores["UPPER_DOMINANT"] += 2
        elif shoulder_hip <= 0.95:
            scores["LOWER_DOMINANT"] += 2
        else:
            scores["BALANCED"] += 1

    waist_values = [v for v in (waist_chest, waist_hip) if v is not None]
    if waist_values:
        waist_avg = sum(waist_values) / len(waist_values)
        if waist_avg <= 0.78:
            scores["WAIST_LINE"] += 2
        elif waist_avg >= 0.95:
            scores["STRAIGHT"] += 1

    if abdomen_chest is not None and abdomen_chest >= 0.95:
        scores["STRAIGHT"] += 1
    if thigh_waist is not None and thigh_waist >= 0.95:
        scores["LOWER_DOMINANT"] += 1

    if not scores:
        return "UNKNOWN"
    return scores.most_common(1)[0][0]


def _severity(value: float | None, caution: float, warning: float) -> str:
    if value is None:
        return "unknown"
    if value >= warning:
        return "high"
    if value >= caution:
        return "medium"
    return "low"


def _judgements(posture_metrics: dict[str, Any], shape_metrics: dict[str, Any]) -> list[MetricJudgement]:
    items = [
        ("shoulder_tilt", "어깨 기울기", posture_metrics.get("shoulder_tilt_deg", {}).get("mean"), 2.5, 5.0),
        ("pelvis_tilt", "골반 기울기", posture_metrics.get("hip_tilt_deg", {}).get("mean"), 2.5, 5.0),
        ("arm_balance", "팔 좌우 균형", posture_metrics.get("arm_length_asymmetry_ratio", {}).get("mean"), 0.04, 0.08),
        ("leg_balance", "다리 좌우 균형", posture_metrics.get("leg_length_asymmetry_ratio", {}).get("mean"), 0.04, 0.08),
        ("shoulder_hip_ratio", "어깨/골반 비율", shape_metrics.get("shoulder_to_hip_ratio", {}).get("mean"), 1.25, 1.6),
        ("waist_line", "허리 라인", shape_metrics.get("waist_to_chest_ratio", {}).get("mean"), 0.9, 1.0),
    ]
    judgements: list[MetricJudgement] = []
    for key, label, value, caution, warning in items:
        severity = _severity(value, caution, warning)
        if severity == "high":
            message = f"{label} 값이 여러 사진에서 높게 나타납니다."
        elif severity == "medium":
            message = f"{label} 값을 확인할 필요가 있습니다."
        elif severity == "low":
            message = f"{label} 값은 비교적 안정적입니다."
        else:
            message = f"{label} 값을 안정적으로 측정하지 못했습니다."
        judgements.append(MetricJudgement(key=key, label=label, value=_round(value), severity=severity, message=message))
    return judgements


def _priority_parts(judgements: list[MetricJudgement]) -> list[PriorityPart]:
    mapping = {
        "shoulder_tilt": ("shoulder_tilt", "어깨 기울기가 반복적으로 나타납니다."),
        "pelvis_tilt": ("pelvis_tilt", "골반 기울기가 반복적으로 나타납니다."),
        "arm_balance": ("shoulder_tilt", "팔 좌우 균형 차이는 어깨/상체 정렬 영향일 수 있습니다."),
        "leg_balance": ("pelvis_tilt", "다리 좌우 균형 차이는 골반/하체 정렬 영향일 수 있습니다."),
        "shoulder_hip_ratio": ("upper_body", "상체 실루엣 비율이 높게 나타납니다."),
        "waist_line": ("core", "허리/복부 실루엣을 확인할 필요가 있습니다."),
    }
    priorities = []
    for item in judgements:
        if item.severity not in {"medium", "high"}:
            continue
        target, reason = mapping[item.key]
        priorities.append(PriorityPart(targetIssue=target, severity=item.severity, reason=reason))
    return priorities[:4]


def analyze_body_images(image_paths: list[str], output_dir: str, text_input: str | None = None) -> BodyAnalysisResponse:
    if not image_paths:
        raise ValueError("At least one image is required.")

    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    analyses = []
    debug_images = []
    for image_path in image_paths:
        with quiet_mediapipe_logs():
            _, debug_image_path, analysis = analyze_image(image_path, str(output), min_detection_confidence=0.5)
        analyses.append(analysis)
        debug_images.append(os.path.abspath(debug_image_path))

    posture_keys = [
        "shoulder_tilt_deg",
        "hip_tilt_deg",
        "vertical_axis_tilt_deg",
        "arm_length_asymmetry_ratio",
        "leg_length_asymmetry_ratio",
        "skeletal_symmetry_score",
    ]
    shape_keys = [
        "chest_width_ratio",
        "waist_width_ratio",
        "abdomen_width_ratio",
        "silhouette_hip_width_ratio",
        "thigh_width_ratio",
        "shoulder_to_hip_ratio",
        "torso_leg_ratio",
        "waist_to_chest_ratio",
        "waist_to_hip_ratio",
        "abdomen_to_chest_ratio",
        "thigh_to_waist_ratio",
    ]

    posture_metrics = {
        key: _metric_summary(analyses, key, absolute=key in {"shoulder_tilt_deg", "hip_tilt_deg"})
        for key in posture_keys
    }
    shape_metrics = {key: _metric_summary(analyses, key) for key in shape_keys}

    body_type = _body_type({key: value["mean"] for key, value in shape_metrics.items()})
    judgements = _judgements(posture_metrics, shape_metrics)
    priority_parts = _priority_parts(judgements)

    shoulder_tilt = posture_metrics["shoulder_tilt_deg"]["mean"]
    pelvis_tilt = posture_metrics["hip_tilt_deg"]["mean"]
    shoulder_hip = shape_metrics["shoulder_to_hip_ratio"]["mean"]
    torso_leg = shape_metrics["torso_leg_ratio"]["mean"]
    balance_score = _balance_score(analyses)

    comparison_summary = f"{len(analyses)}장 기준 {body_type} 경향, 어깨 {_round(shoulder_tilt)}도/골반 {_round(pelvis_tilt)}도 정렬 이슈를 확인했습니다."
    comparison_detail = (
        "여러 사진의 평균, 범위, 표준편차를 기반으로 골격 정렬과 segmentation 실루엣 비율을 계산했습니다. "
        "2D 사진 기반 참고 분석이므로 옷, 포즈, 카메라 각도 영향을 함께 고려해야 합니다."
    )

    return BodyAnalysisResponse(
        posture=PostureResult(
            shoulderTiltDeg=_round(shoulder_tilt),
            pelvisTiltDeg=_round(pelvis_tilt),
            neckForwardDeg=None,
            balanceScore=balance_score,
            metrics=posture_metrics,
        ),
        bodyShape=BodyShapeResult(
            bodyType=body_type,
            shoulderHipRatio=_round(shoulder_hip),
            torsoLegRatio=_round(torso_leg),
            waistChestRatio=_round(shape_metrics["waist_to_chest_ratio"]["mean"]),
            waistHipRatio=_round(shape_metrics["waist_to_hip_ratio"]["mean"]),
            abdomenChestRatio=_round(shape_metrics["abdomen_to_chest_ratio"]["mean"]),
            thighWaistRatio=_round(shape_metrics["thigh_to_waist_ratio"]["mean"]),
            metrics=shape_metrics,
        ),
        judgements=judgements,
        priorityParts=priority_parts,
        comparisonSummary=comparison_summary,
        comparisonDetail=comparison_detail,
        textSummary=text_input.strip() if text_input else None,
        debugImages=debug_images,
        raw={
            "createdAt": datetime.now().isoformat(timespec="seconds"),
            "imageCount": len(analyses),
            "analyses": analyses,
        },
    )
