import csv
import hashlib
import json
import os

import numpy as np

try:
    from .analyze_body import analyze_image
except ImportError:
    from analyze_body import analyze_image


# Keep body-shape features separate from pose conditions such as arm position or tilt.
FEATURE_NAMES = [
    "chest_width_ratio",
    "waist_width_ratio",
    "abdomen_width_ratio",
    "silhouette_hip_width_ratio",
    "thigh_width_ratio",
    "calf_width_ratio",
    "waist_to_chest_ratio",
    "waist_to_hip_ratio",
    "abdomen_to_chest_ratio",
    "thigh_to_waist_ratio",
    "calf_to_thigh_ratio",
    "silhouette_area_ratio",
    "shoulder_width_ratio",
    "hip_width_ratio",
    "shoulder_to_hip_ratio",
    "torso_leg_ratio",
]


def resolve_image_path(labels_path, image_path):
    if os.path.isabs(image_path):
        return image_path
    return os.path.abspath(os.path.join(os.path.dirname(labels_path), image_path))


def automatic_split(subject_id):
    bucket = int(hashlib.sha256(subject_id.encode("utf-8")).hexdigest()[:8], 16) % 100
    if bucket < 70:
        return "train"
    if bucket < 85:
        return "val"
    return "test"


def load_manifest(labels_path):
    rows = []
    with open(labels_path, newline="", encoding="utf-8-sig") as file:
        reader = csv.DictReader(file)
        required = {"image_path", "body_type", "subject_id"}
        if not reader.fieldnames or not required.issubset(reader.fieldnames):
            raise ValueError("CSV에는 image_path, body_type, subject_id 열이 필요합니다.")

        for line_number, row in enumerate(reader, start=2):
            image_path = (row.get("image_path") or "").strip()
            label = (row.get("body_type") or "").strip()
            subject_id = (row.get("subject_id") or "").strip()
            split = (row.get("split") or "").strip().lower()
            if not image_path or not label or not subject_id:
                raise ValueError(f"CSV {line_number}행에 빈 필수 값이 있습니다.")
            if split and split not in {"train", "val", "test"}:
                raise ValueError(f"CSV {line_number}행 split은 train/val/test 중 하나여야 합니다.")
            resolved = resolve_image_path(labels_path, image_path)
            if not os.path.isfile(resolved):
                raise FileNotFoundError(f"CSV {line_number}행 이미지를 찾을 수 없습니다: {resolved}")
            rows.append({
                "image_path": resolved,
                "body_type": label,
                "subject_id": subject_id,
                "split": split or automatic_split(subject_id),
            })

    if not rows:
        raise ValueError("CSV에 학습할 이미지가 없습니다.")

    subject_splits = {}
    for row in rows:
        previous = subject_splits.setdefault(row["subject_id"], row["split"])
        if previous != row["split"]:
            raise ValueError(
                f"동일 인물 {row['subject_id']}이 {previous}와 {row['split']}에 동시에 포함됐습니다."
            )
    return rows


def analysis_for_image(image_path, cache_dir, min_confidence=0.5):
    cache_key = hashlib.sha256(os.path.abspath(image_path).encode("utf-8")).hexdigest()[:16]
    item_dir = os.path.join(cache_dir, cache_key)
    base_name = os.path.splitext(os.path.basename(image_path))[0]
    json_path = os.path.join(item_dir, f"{base_name}_body_analysis.json")
    if os.path.isfile(json_path) and os.path.getmtime(json_path) >= os.path.getmtime(image_path):
        with open(json_path, encoding="utf-8") as file:
            return json.load(file)

    _, _, output = analyze_image(image_path, item_dir, min_confidence)
    return output


def feature_vector(analysis):
    metrics = analysis["metrics"]
    values = []
    for name in FEATURE_NAMES:
        value = metrics.get(name)
        values.append(np.nan if value is None else float(value))
    return np.asarray(values, dtype=np.float64)
