"""Bounded on-device multi-pose check, with a pinned official task asset."""
from __future__ import annotations
import hashlib
import math
from pathlib import Path
import os

MODEL_URL = 'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task'
MODEL_SHA256 = '59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a'
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / '.cache/models/pose_landmarker_lite.task'


def validate_asset(path):
    path = Path(path).expanduser().resolve()
    if not path.is_file() or path.stat().st_size > 20_000_000:
        raise ValueError('공식 포즈 검사 모델이 없거나 크기가 잘못됐습니다.')
    if hashlib.sha256(path.read_bytes()).hexdigest() != MODEL_SHA256:
        raise ValueError('포즈 검사 모델의 SHA256이 공식 고정 버전과 일치하지 않습니다.')
    return path


def credible_pose(landmarks):
    """Ignore tiny/partial detections; this is not a person-count guarantee."""
    indices = (0, 11, 12, 23, 24, 27, 28)
    points = []
    for i in indices:
        if i >= len(landmarks):
            continue
        item = landmarks[i]
        values = [getattr(item, k, None) for k in ('x', 'y', 'visibility')]
        if all(isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) for v in values):
            if 0 <= item.x <= 1 and 0 <= item.y <= 1 and .5 <= item.visibility <= 1:
                points.append(item)
    return len(points) >= 4 and max(p.y for p in points) - min(p.y for p in points) >= .15


class PoseGuard:
    def __init__(self, path=DEFAULT_MODEL):
        import mediapipe as mp
        from mediapipe.tasks import python
        from mediapipe.tasks.python import vision
        self.mp = mp
        self.detector = vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
            base_options=python.BaseOptions(model_asset_path=str(validate_asset(path))),
            running_mode=vision.RunningMode.IMAGE, num_poses=3,
            min_pose_detection_confidence=.5, min_pose_presence_confidence=.5))

    def inspect(self, rgb):
        import numpy as np
        detected = self.detector.detect(self.mp.Image(image_format=self.mp.ImageFormat.SRGB,
                                                     data=np.ascontiguousarray(rgb)))
        count = sum(credible_pose(pose) for pose in detected.pose_landmarks)
        return {'status': 'checked' if count else 'inconclusive', 'detected_poses': count,
                'multiple_people_detected': count > 1, 'detection_limit': 3,
                'note': '검출되지 않은 인물이나 사진 속 인쇄된 인물이 있을 수 있습니다. 인물 수 보장은 아닙니다.'}

    def close(self):
        self.detector.close()


def create_pose_guard():
    configured = os.environ.get('AI_POSE_MODEL_PATH')
    if configured:
        return PoseGuard(configured)
    return PoseGuard(DEFAULT_MODEL) if DEFAULT_MODEL.is_file() else None
