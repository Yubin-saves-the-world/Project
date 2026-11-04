import argparse
import json
import math
import os
from datetime import datetime

import cv2
import mediapipe as mp
import numpy as np


DISCLAIMER = (
    "This is not a medical diagnosis. It is a visual posture, silhouette, and "
    "body-ratio analysis based on a single 2D image. Results can change with "
    "camera angle, pose, lens distortion, clothes, lighting, and whether arms "
    "touch the torso."
)


LANDMARKS = mp.solutions.pose.PoseLandmark


def distance(a, b):
    return math.sqrt((a["x"] - b["x"]) ** 2 + (a["y"] - b["y"]) ** 2)


def midpoint(a, b):
    return {
        "x": (a["x"] + b["x"]) / 2,
        "y": (a["y"] + b["y"]) / 2,
        "visibility": min(a.get("visibility", 1.0), b.get("visibility", 1.0)),
    }


def line_tilt_deg(left, right):
    dx = right["x"] - left["x"]
    dy = right["y"] - left["y"]
    if abs(dx) < 1e-9:
        return 90.0
    angle = math.degrees(math.atan2(dy, dx))
    if angle > 90:
        angle -= 180
    elif angle < -90:
        angle += 180
    return angle


def vertical_tilt_deg(top, bottom):
    dx = bottom["x"] - top["x"]
    dy = bottom["y"] - top["y"]
    if abs(dy) < 1e-9:
        return 90.0
    return math.degrees(math.atan2(dx, dy))


def clamp(value, low, high):
    return max(low, min(high, value))


def safe_ratio(numerator, denominator):
    if denominator is None or abs(denominator) < 1e-9:
        return None
    return numerator / denominator


def round_nested(value, digits=4):
    if isinstance(value, dict):
        return {key: round_nested(item, digits) for key, item in value.items()}
    if isinstance(value, list):
        return [round_nested(item, digits) for item in value]
    if isinstance(value, float):
        return round(value, digits)
    return value


def landmark_to_dict(landmark):
    return {
        "x": float(landmark.x),
        "y": float(landmark.y),
        "z": float(landmark.z),
        "visibility": float(landmark.visibility),
    }


def get_required_points(landmarks):
    names = {
        "left_shoulder": LANDMARKS.LEFT_SHOULDER,
        "right_shoulder": LANDMARKS.RIGHT_SHOULDER,
        "left_hip": LANDMARKS.LEFT_HIP,
        "right_hip": LANDMARKS.RIGHT_HIP,
        "left_knee": LANDMARKS.LEFT_KNEE,
        "right_knee": LANDMARKS.RIGHT_KNEE,
        "left_ankle": LANDMARKS.LEFT_ANKLE,
        "right_ankle": LANDMARKS.RIGHT_ANKLE,
        "left_ear": LANDMARKS.LEFT_EAR,
        "right_ear": LANDMARKS.RIGHT_EAR,
    }
    return {name: landmark_to_dict(landmarks[index.value]) for name, index in names.items()}


def get_all_points(landmarks):
    return {
        landmark.name.lower(): landmark_to_dict(landmarks[landmark.value])
        for landmark in LANDMARKS
    }


def joint_angle_deg(a, b, c):
    """Return the smaller 2D angle ABC in degrees."""
    ba = np.array([a["x"] - b["x"], a["y"] - b["y"]], dtype=float)
    bc = np.array([c["x"] - b["x"], c["y"] - b["y"]], dtype=float)
    denominator = np.linalg.norm(ba) * np.linalg.norm(bc)
    if denominator < 1e-9:
        return None
    cosine = float(np.dot(ba, bc) / denominator)
    return math.degrees(math.acos(clamp(cosine, -1.0, 1.0)))


def interpolate(a, b, fraction):
    return {
        "x": a["x"] + (b["x"] - a["x"]) * fraction,
        "y": a["y"] + (b["y"] - a["y"]) * fraction,
        "visibility": min(a.get("visibility", 1.0), b.get("visibility", 1.0)),
    }


def build_virtual_points(points):
    shoulder = midpoint(points["left_shoulder"], points["right_shoulder"])
    hip = midpoint(points["left_hip"], points["right_hip"])
    ear = midpoint(points["left_ear"], points["right_ear"])
    knee = midpoint(points["left_knee"], points["right_knee"])
    ankle = midpoint(points["left_ankle"], points["right_ankle"])
    return {
        "head_center": ear,
        "neck_center": interpolate(ear, shoulder, 0.72),
        "shoulder_center": shoulder,
        "upper_chest_center": interpolate(shoulder, hip, 0.20),
        "chest_center": interpolate(shoulder, hip, 0.35),
        "waist_center": interpolate(shoulder, hip, 0.62),
        "abdomen_center": interpolate(shoulder, hip, 0.78),
        "pelvis_center": hip,
        "knee_center": knee,
        "ankle_center": ankle,
    }


def estimate_body_box(points):
    xs = [point["x"] for point in points.values()]
    ys = [point["y"] for point in points.values()]
    return {
        "min_x": min(xs),
        "max_x": max(xs),
        "min_y": min(ys),
        "max_y": max(ys),
        "width": max(xs) - min(xs),
        "height": max(ys) - min(ys),
    }


def compute_metrics(points, all_points):
    left_shoulder = points["left_shoulder"]
    right_shoulder = points["right_shoulder"]
    left_hip = points["left_hip"]
    right_hip = points["right_hip"]
    left_knee = points["left_knee"]
    right_knee = points["right_knee"]
    left_ankle = points["left_ankle"]
    right_ankle = points["right_ankle"]
    left_ear = points["left_ear"]
    right_ear = points["right_ear"]

    shoulder_center = midpoint(left_shoulder, right_shoulder)
    hip_center = midpoint(left_hip, right_hip)
    knee_center = midpoint(left_knee, right_knee)
    ankle_center = midpoint(left_ankle, right_ankle)
    ear_center = midpoint(left_ear, right_ear)

    body_box = estimate_body_box(points)
    body_height = max(distance(ear_center, ankle_center), body_box["height"])
    shoulder_width = distance(left_shoulder, right_shoulder)
    hip_width = distance(left_hip, right_hip)
    torso_length = distance(shoulder_center, hip_center)
    leg_length = distance(hip_center, ankle_center)
    left_side = distance(left_shoulder, left_hip) + distance(left_hip, left_ankle)
    right_side = distance(right_shoulder, right_hip) + distance(right_hip, right_ankle)
    side_diff_ratio = safe_ratio(abs(left_side - right_side), max(left_side, right_side))
    symmetry_score = None if side_diff_ratio is None else clamp(1.0 - side_diff_ratio, 0.0, 1.0)

    shoulder_tilt = line_tilt_deg(left_shoulder, right_shoulder)
    hip_tilt = line_tilt_deg(left_hip, right_hip)
    vertical_axis_tilt = vertical_tilt_deg(shoulder_center, hip_center)

    left_arm = distance(all_points["left_shoulder"], all_points["left_elbow"]) + distance(
        all_points["left_elbow"], all_points["left_wrist"]
    )
    right_arm = distance(all_points["right_shoulder"], all_points["right_elbow"]) + distance(
        all_points["right_elbow"], all_points["right_wrist"]
    )
    left_leg = distance(all_points["left_hip"], all_points["left_knee"]) + distance(
        all_points["left_knee"], all_points["left_ankle"]
    )
    right_leg = distance(all_points["right_hip"], all_points["right_knee"]) + distance(
        all_points["right_knee"], all_points["right_ankle"]
    )
    arm_asymmetry = safe_ratio(abs(left_arm - right_arm), max(left_arm, right_arm))
    leg_asymmetry = safe_ratio(abs(left_leg - right_leg), max(left_leg, right_leg))
    center_offsets = {
        "head_to_shoulders": safe_ratio(ear_center["x"] - shoulder_center["x"], body_height),
        "shoulders_to_hips": safe_ratio(shoulder_center["x"] - hip_center["x"], body_height),
        "hips_to_knees": safe_ratio(hip_center["x"] - knee_center["x"], body_height),
        "knees_to_ankles": safe_ratio(knee_center["x"] - ankle_center["x"], body_height),
    }

    return {
        "shoulder_tilt_deg": shoulder_tilt,
        "hip_tilt_deg": hip_tilt,
        "vertical_axis_tilt_deg": vertical_axis_tilt,
        "shoulder_width_ratio": safe_ratio(shoulder_width, body_height),
        "hip_width_ratio": safe_ratio(hip_width, body_height),
        "shoulder_to_hip_ratio": safe_ratio(shoulder_width, hip_width),
        "torso_leg_ratio": safe_ratio(torso_length, leg_length),
        "left_side_length_ratio": safe_ratio(left_side, body_height),
        "right_side_length_ratio": safe_ratio(right_side, body_height),
        "symmetry_like_score": symmetry_score,
        "head_tilt_deg": line_tilt_deg(left_ear, right_ear),
        "knee_line_tilt_deg": line_tilt_deg(left_knee, right_knee),
        "ankle_line_tilt_deg": line_tilt_deg(left_ankle, right_ankle),
        "lower_body_axis_tilt_deg": vertical_tilt_deg(hip_center, ankle_center),
        "head_center_offset_ratio": center_offsets["head_to_shoulders"],
        "shoulder_hip_center_offset_ratio": center_offsets["shoulders_to_hips"],
        "hip_knee_center_offset_ratio": center_offsets["hips_to_knees"],
        "knee_ankle_center_offset_ratio": center_offsets["knees_to_ankles"],
        "left_elbow_angle_deg": joint_angle_deg(all_points["left_shoulder"], all_points["left_elbow"], all_points["left_wrist"]),
        "right_elbow_angle_deg": joint_angle_deg(all_points["right_shoulder"], all_points["right_elbow"], all_points["right_wrist"]),
        "left_knee_angle_deg": joint_angle_deg(all_points["left_hip"], all_points["left_knee"], all_points["left_ankle"]),
        "right_knee_angle_deg": joint_angle_deg(all_points["right_hip"], all_points["right_knee"], all_points["right_ankle"]),
        "arm_length_asymmetry_ratio": arm_asymmetry,
        "leg_length_asymmetry_ratio": leg_asymmetry,
        "skeletal_symmetry_score": clamp(1.0 - np.mean([arm_asymmetry or 0.0, leg_asymmetry or 0.0, side_diff_ratio or 0.0]), 0.0, 1.0),
        "raw_pixel": {
            "body_height_estimate": body_height,
            "shoulder_width": shoulder_width,
            "hip_width": hip_width,
            "torso_length": torso_length,
            "leg_length": leg_length,
            "left_side_length": left_side,
            "right_side_length": right_side,
        },
        "centers": {
            "ear": ear_center,
            "shoulder": shoulder_center,
            "hip": hip_center,
            "knee": knee_center,
            "ankle": ankle_center,
        },
        "center_offsets": center_offsets,
    }


def normalized_to_pixel(point, width, height):
    return int(clamp(point["x"], 0.0, 1.0) * (width - 1)), int(clamp(point["y"], 0.0, 1.0) * (height - 1))


def largest_true_segment(indices):
    if len(indices) == 0:
        return None

    best_start = indices[0]
    best_end = indices[0]
    start = indices[0]
    prev = indices[0]

    for value in indices[1:]:
        if value == prev + 1:
            prev = value
            continue

        if prev - start > best_end - best_start:
            best_start = start
            best_end = prev
        start = value
        prev = value

    if prev - start > best_end - best_start:
        best_start = start
        best_end = prev

    return best_start, best_end


def width_at_y(mask, y, x_min, x_max, band=4):
    height, width = mask.shape
    y = int(clamp(y, 0, height - 1))
    x_min = int(clamp(x_min, 0, width - 1))
    x_max = int(clamp(x_max, x_min + 1, width - 1))
    y0 = max(0, y - band)
    y1 = min(height, y + band + 1)

    row = np.any(mask[y0:y1, x_min:x_max + 1], axis=0)
    indices = np.where(row)[0]
    segment = largest_true_segment(indices)
    if segment is None:
        return None

    left, right = segment
    return {
        "width_px": int(right - left + 1),
        "left_x": int(x_min + left),
        "right_x": int(x_min + right),
        "y": int(y),
    }


def body_mask_from_segmentation(segmentation_mask, threshold=0.2):
    mask = segmentation_mask > threshold
    mask = mask.astype(np.uint8) * 255
    kernel = np.ones((5, 5), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    return mask > 0


def compute_silhouette_metrics(image_shape, segmentation_mask, points):
    height, width = image_shape[:2]
    mask = body_mask_from_segmentation(segmentation_mask)
    ys, xs = np.where(mask)
    if len(xs) == 0 or len(ys) == 0:
        return {}, {}

    left_shoulder_px = normalized_to_pixel(points["left_shoulder"], width, height)
    right_shoulder_px = normalized_to_pixel(points["right_shoulder"], width, height)
    left_hip_px = normalized_to_pixel(points["left_hip"], width, height)
    right_hip_px = normalized_to_pixel(points["right_hip"], width, height)
    left_knee_px = normalized_to_pixel(points["left_knee"], width, height)
    right_knee_px = normalized_to_pixel(points["right_knee"], width, height)
    left_ankle_px = normalized_to_pixel(points["left_ankle"], width, height)
    right_ankle_px = normalized_to_pixel(points["right_ankle"], width, height)
    left_ear_px = normalized_to_pixel(points["left_ear"], width, height)
    right_ear_px = normalized_to_pixel(points["right_ear"], width, height)

    shoulder_y = int((left_shoulder_px[1] + right_shoulder_px[1]) / 2)
    hip_y = int((left_hip_px[1] + right_hip_px[1]) / 2)
    knee_y = int((left_knee_px[1] + right_knee_px[1]) / 2)
    ankle_y = int((left_ankle_px[1] + right_ankle_px[1]) / 2)
    ear_y = int((left_ear_px[1] + right_ear_px[1]) / 2)

    body_height_px = max(1, ankle_y - ear_y)
    shoulder_width_px = max(1, abs(right_shoulder_px[0] - left_shoulder_px[0]))
    torso_x_min = min(left_shoulder_px[0], right_shoulder_px[0], left_hip_px[0], right_hip_px[0])
    torso_x_max = max(left_shoulder_px[0], right_shoulder_px[0], left_hip_px[0], right_hip_px[0])
    margin = int(shoulder_width_px * 0.35)
    x_min = max(0, torso_x_min - margin)
    x_max = min(width - 1, torso_x_max + margin)

    torso_span = max(1, hip_y - shoulder_y)
    leg_span = max(1, ankle_y - hip_y)
    levels = {
        "shoulder": shoulder_y,
        "upper_chest": shoulder_y + int(torso_span * 0.12),
        "chest": shoulder_y + int(torso_span * 0.22),
        "lower_chest": shoulder_y + int(torso_span * 0.42),
        "waist": shoulder_y + int(torso_span * 0.62),
        "abdomen": shoulder_y + int(torso_span * 0.78),
        "hip": hip_y,
        "upper_thigh": hip_y + int(leg_span * 0.14),
        "thigh": hip_y + int(leg_span * 0.28),
        "lower_thigh": hip_y + int(leg_span * 0.40),
        "knee": knee_y,
        "calf": knee_y + int(max(1, ankle_y - knee_y) * 0.45),
        "lower_calf": knee_y + int(max(1, ankle_y - knee_y) * 0.72),
        "ankle": ankle_y,
    }

    widths = {
        name: width_at_y(mask, y, x_min, x_max, band=5)
        for name, y in levels.items()
    }

    def width_ratio(name):
        item = widths.get(name)
        if not item:
            return None
        return item["width_px"] / body_height_px

    silhouette_bbox = {
        "min_x": int(xs.min()),
        "max_x": int(xs.max()),
        "min_y": int(ys.min()),
        "max_y": int(ys.max()),
        "width_px": int(xs.max() - xs.min() + 1),
        "height_px": int(ys.max() - ys.min() + 1),
    }
    silhouette_area_px = int(mask.sum())
    silhouette_area_ratio = silhouette_area_px / float(body_height_px * body_height_px)

    chest = width_ratio("chest")
    waist = width_ratio("waist")
    abdomen = width_ratio("abdomen")
    hip = width_ratio("hip")
    thigh = width_ratio("thigh")
    calf = width_ratio("calf")

    metrics = {
        "chest_width_ratio": chest,
        "waist_width_ratio": waist,
        "abdomen_width_ratio": abdomen,
        "silhouette_hip_width_ratio": hip,
        "thigh_width_ratio": thigh,
        "calf_width_ratio": calf,
        "waist_to_chest_ratio": safe_ratio(waist, chest),
        "waist_to_hip_ratio": safe_ratio(waist, hip),
        "abdomen_to_chest_ratio": safe_ratio(abdomen, chest),
        "thigh_to_waist_ratio": safe_ratio(thigh, waist),
        "calf_to_thigh_ratio": safe_ratio(calf, thigh),
        "silhouette_area_ratio": silhouette_area_ratio,
    }

    debug = {
        "mask": mask,
        "widths": widths,
        "x_range": {"min_x": x_min, "max_x": x_max},
        "body_height_px": body_height_px,
        "silhouette_bbox": silhouette_bbox,
        "silhouette_area_px": silhouette_area_px,
    }

    return metrics, debug


def make_interpretation(metrics):
    notes = []

    shoulder_abs = abs(metrics["shoulder_tilt_deg"])
    hip_abs = abs(metrics["hip_tilt_deg"])

    if shoulder_abs < 2:
        notes.append("Shoulder line is close to level in this image.")
    elif shoulder_abs < 5:
        notes.append("Small shoulder height difference is visible.")
    else:
        notes.append("Noticeable shoulder height difference is visible.")

    if hip_abs < 2:
        notes.append("Hip line is close to level in this image.")
    elif hip_abs < 5:
        notes.append("Small hip height difference is visible.")
    else:
        notes.append("Noticeable hip height difference is visible.")

    symmetry = metrics["symmetry_like_score"]
    if symmetry is not None:
        if symmetry >= 0.97:
            notes.append("Left/right side-length balance is high by this 2D estimate.")
        elif symmetry >= 0.93:
            notes.append("Left/right side-length balance is moderate by this 2D estimate.")
        else:
            notes.append("Left/right side-length difference is relatively large by this 2D estimate.")

    notes.append("Use the same pipeline on a target-body photo before comparing metrics.")
    return notes


def draw_debug_image(image_bgr, landmarks, output_path, silhouette_debug=None, virtual_points=None):
    annotated = image_bgr.copy()
    if silhouette_debug and "mask" in silhouette_debug:
        mask = silhouette_debug["mask"]
        overlay = np.zeros_like(annotated)
        overlay[:, :] = (0, 160, 255)
        annotated = np.where(mask[:, :, None], cv2.addWeighted(annotated, 0.7, overlay, 0.3, 0), annotated)

        colors = {
            "shoulder": (40, 255, 40),
            "upper_chest": (40, 235, 100),
            "chest": (50, 220, 50),
            "lower_chest": (80, 210, 180),
            "waist": (255, 220, 0),
            "abdomen": (0, 180, 255),
            "hip": (255, 120, 0),
            "upper_thigh": (255, 80, 190),
            "thigh": (220, 80, 255),
            "lower_thigh": (190, 100, 255),
            "knee": (150, 140, 255),
            "calf": (180, 180, 255),
            "lower_calf": (200, 200, 255),
            "ankle": (220, 220, 255),
        }
        for name, item in silhouette_debug.get("widths", {}).items():
            if not item:
                continue
            color = colors.get(name, (255, 255, 255))
            cv2.line(annotated, (item["left_x"], item["y"]), (item["right_x"], item["y"]), color, 3)
            cv2.circle(annotated, (item["left_x"], item["y"]), 6, color, -1)
            cv2.circle(annotated, (item["right_x"], item["y"]), 6, color, -1)
            cv2.putText(
                annotated,
                name,
                (item["left_x"], max(20, item["y"] - 8)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.55,
                color,
                2,
                cv2.LINE_AA,
            )

    mp.solutions.drawing_utils.draw_landmarks(
        annotated,
        landmarks,
        mp.solutions.pose.POSE_CONNECTIONS,
        landmark_drawing_spec=mp.solutions.drawing_styles.get_default_pose_landmarks_style(),
    )

    height, width = annotated.shape[:2]
    # Make all 33 detected landmarks explicit; the number maps to MediaPipe's index.
    for index, landmark in enumerate(landmarks.landmark):
        if landmark.visibility < 0.35:
            continue
        point = (int(landmark.x * width), int(landmark.y * height))
        cv2.circle(annotated, point, 5, (255, 255, 255), -1)
        cv2.circle(annotated, point, 7, (30, 30, 30), 1)
        cv2.putText(
            annotated,
            str(index),
            (point[0] + 7, point[1] - 7),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.38,
            (255, 255, 255),
            1,
            cv2.LINE_AA,
        )

    if virtual_points:
        virtual_order = [
            "head_center", "neck_center", "shoulder_center", "upper_chest_center",
            "chest_center", "waist_center", "abdomen_center", "pelvis_center",
            "knee_center", "ankle_center",
        ]
        pixel_points = {
            name: normalized_to_pixel(virtual_points[name], width, height)
            for name in virtual_order
        }
        detected_pixels = {
            landmark.name.lower(): normalized_to_pixel(
                landmark_to_dict(landmarks.landmark[landmark.value]), width, height
            )
            for landmark in LANDMARKS
        }
        # Analysis mesh: center-to-side axes and torso diagonals expose rotation/asymmetry.
        mesh_connections = [
            (pixel_points["neck_center"], detected_pixels["left_shoulder"]),
            (pixel_points["neck_center"], detected_pixels["right_shoulder"]),
            (pixel_points["shoulder_center"], detected_pixels["left_hip"]),
            (pixel_points["shoulder_center"], detected_pixels["right_hip"]),
            (detected_pixels["left_shoulder"], detected_pixels["right_hip"]),
            (detected_pixels["right_shoulder"], detected_pixels["left_hip"]),
            (pixel_points["pelvis_center"], detected_pixels["left_knee"]),
            (pixel_points["pelvis_center"], detected_pixels["right_knee"]),
            (detected_pixels["left_knee"], detected_pixels["right_knee"]),
            (pixel_points["knee_center"], detected_pixels["left_ankle"]),
            (pixel_points["knee_center"], detected_pixels["right_ankle"]),
            (detected_pixels["left_ankle"], detected_pixels["right_ankle"]),
        ]
        for start, end in mesh_connections:
            cv2.line(annotated, start, end, (255, 180, 40), 2)
        for first, second in zip(virtual_order, virtual_order[1:]):
            cv2.line(annotated, pixel_points[first], pixel_points[second], (255, 0, 255), 3)
        for name in virtual_order:
            point = pixel_points[name]
            cv2.circle(annotated, point, 7, (255, 0, 255), -1)
            cv2.circle(annotated, point, 9, (255, 255, 255), 1)
        for name in ("neck_center", "chest_center", "waist_center", "pelvis_center"):
            point = pixel_points[name]
            cv2.putText(
                annotated,
                name.replace("_center", ""),
                (point[0] + 12, point[1] + 4),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.48,
                (255, 0, 255),
                2,
                cv2.LINE_AA,
            )
    cv2.imwrite(output_path, annotated)


def analyze_image(image_path, output_dir, min_detection_confidence):
    image_bgr = cv2.imread(image_path)
    if image_bgr is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)

    with mp.solutions.pose.Pose(
        static_image_mode=True,
        model_complexity=2,
        enable_segmentation=True,
        min_detection_confidence=min_detection_confidence,
    ) as pose:
        result = pose.process(image_rgb)

    if not result.pose_landmarks:
        raise RuntimeError("No body pose detected. Try a clearer full-body front photo.")

    all_points = get_all_points(result.pose_landmarks.landmark)
    points = get_required_points(result.pose_landmarks.landmark)
    virtual_points = build_virtual_points(all_points)
    # Geometry must use equally scaled axes; normalized x/y distort angles on portraits.
    height, width = image_bgr.shape[:2]
    def pixels(items):
        return {key: {**point, "x": point["x"] * width, "y": point["y"] * height}
                for key, point in items.items()}
    pose_metrics = compute_metrics(pixels(points), pixels(all_points))
    silhouette_metrics = {}
    silhouette_debug = {}
    if result.segmentation_mask is not None:
        silhouette_metrics, silhouette_debug = compute_silhouette_metrics(
            image_bgr.shape,
            result.segmentation_mask,
            points,
        )
    metrics = {**silhouette_metrics, **pose_metrics}

    os.makedirs(output_dir, exist_ok=True)
    base_name = os.path.splitext(os.path.basename(image_path))[0]
    json_path = os.path.join(output_dir, f"{base_name}_body_analysis.json")
    debug_image_path = os.path.join(output_dir, f"{base_name}_pose_debug.jpg")

    draw_debug_image(
        image_bgr,
        result.pose_landmarks,
        debug_image_path,
        silhouette_debug,
        virtual_points,
    )

    output = {
        "schema_version": "body-analysis-mvp-v3",
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "image_path": os.path.abspath(image_path),
        "disclaimer": DISCLAIMER,
        "method": {
            "pipeline": "MediaPipe Pose Segmentation + OpenCV + Python",
            "coordinate_system": "Normalized landmarks; pixel coordinates for geometry",
            "tracked_landmarks": 33,
            "virtual_centerline_landmarks": len(virtual_points),
            "silhouette_cross_sections": len(silhouette_debug.get("widths", {})),
            "note": "Silhouette ratios estimate visible 2D width, not fat, muscle, or centimeter measurements.",
        },
        "quality": {
            "min_landmark_visibility": min(point["visibility"] for point in points.values()),
            "mean_landmark_visibility": float(np.mean([point["visibility"] for point in points.values()])),
        },
        "metrics": metrics,
        "metric_groups": {
            "silhouette_body_shape": silhouette_metrics,
            "pose_posture": pose_metrics,
        },
        "interpretation": make_interpretation(metrics),
        "landmarks": all_points,
        "virtual_landmarks": virtual_points,
        "silhouette_debug": {
            key: value
            for key, value in silhouette_debug.items()
            if key != "mask"
        },
        "debug_image_path": os.path.abspath(debug_image_path),
    }

    output = round_nested(output)
    with open(json_path, "w", encoding="utf-8") as file:
        json.dump(output, file, ensure_ascii=False, indent=2)

    return json_path, debug_image_path, output


def metric_text(metrics):
    return "\n".join([
        "  [실루엣 체형]",
        f"  가슴 폭 비율: {metrics.get('chest_width_ratio')}",
        f"  허리 폭 비율: {metrics.get('waist_width_ratio')}",
        f"  복부 폭 비율: {metrics.get('abdomen_width_ratio')}",
        f"  골반 실루엣 폭 비율: {metrics.get('silhouette_hip_width_ratio')}",
        f"  허벅지 폭 비율: {metrics.get('thigh_width_ratio')}",
        f"  종아리 폭 비율: {metrics.get('calf_width_ratio')}",
        f"  허리/가슴 비율: {metrics.get('waist_to_chest_ratio')}",
        f"  허리/골반 비율: {metrics.get('waist_to_hip_ratio')}",
        f"  허벅지/허리 비율: {metrics.get('thigh_to_waist_ratio')}",
        f"  전체 실루엣 면적 비율: {metrics.get('silhouette_area_ratio')}",
        "",
        "  [자세 보조 지표]",
        f"  머리 기울기: {metrics['head_tilt_deg']}도",
        f"  어깨 기울기: {metrics['shoulder_tilt_deg']}도",
        f"  골반 기울기: {metrics['hip_tilt_deg']}도",
        f"  무릎선 기울기: {metrics['knee_line_tilt_deg']}도",
        f"  몸 중심축 기울기: {metrics['vertical_axis_tilt_deg']}도",
        f"  하체 중심축 기울기: {metrics['lower_body_axis_tilt_deg']}도",
        f"  어깨/골반 골격 비율: {metrics['shoulder_to_hip_ratio']}",
        f"  상체/하체 골격 비율: {metrics['torso_leg_ratio']}",
        f"  좌우 균형 점수: {metrics['symmetry_like_score']}",
        f"  확장 골격 균형 점수: {metrics['skeletal_symmetry_score']}",
        f"  팔 길이 좌우 차이 비율: {metrics['arm_length_asymmetry_ratio']}",
        f"  다리 길이 좌우 차이 비율: {metrics['leg_length_asymmetry_ratio']}",
    ])


def print_summary(image_path, json_path, debug_image_path, output):
    metrics = output["metrics"]
    print(f"사진: {os.path.basename(image_path)}")
    print(metric_text(metrics))
    print("저장:")
    print(f"  JSON: {json_path}")
    print(f"  디버그 이미지: {debug_image_path}")


def main():
    parser = argparse.ArgumentParser(description="Fast MVP body posture/ratio analyzer.")
    parser.add_argument("--image", required=True, help="Path to a front-facing full-body image.")
    parser.add_argument("--out", default="results", help="Output directory.")
    parser.add_argument("--min-confidence", type=float, default=0.5)
    parser.add_argument(
        "--format",
        choices=["json", "summary"],
        default="json",
        help="Terminal output format. JSON files are always saved.",
    )
    args = parser.parse_args()

    json_path, debug_image_path, output = analyze_image(
        args.image,
        args.out,
        args.min_confidence,
    )

    if args.format == "summary":
        print_summary(args.image, json_path, debug_image_path, output)
    else:
        print(json.dumps({
            "json": os.path.abspath(json_path),
            "debug_image": os.path.abspath(debug_image_path),
            "key_metrics": output["metrics"],
            "disclaimer": DISCLAIMER,
        }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
