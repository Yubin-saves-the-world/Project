"""Small frozen-DINOv3 classifier loaded as validated JSON, never as pickle."""
import json
from pathlib import Path
import numpy as np

from .dinov3_features import MODEL_ID, MODEL_REVISION

FEATURE_SCHEMA = 'dinov3-cls-patch-mean-v1'
CLASSES = {'weak', 'medium', 'clear'}


class ContourClassifier:
    def __init__(self, path):
        path = Path(path)
        if path.stat().st_size > 2 * 1024 * 1024:
            raise ValueError('분류기 JSON 파일이 너무 큽니다.')
        data = json.loads(path.read_text())
        if data.get('withdrawn') is True:
            raise ValueError('철회된 분류기는 사용할 수 없습니다.')
        if (data.get('schema_version') != 1 or data.get('task') != 'upper_arm_contour_visibility'
                or data.get('feature_schema') != FEATURE_SCHEMA or data.get('model_id') != MODEL_ID
                or data.get('model_revision') != MODEL_REVISION):
            raise ValueError('분류기 버전·특징·공식 모델 리비전이 일치하지 않습니다.')
        self.labels = data['classes']
        if len(self.labels) not in (2, 3) or len(set(self.labels)) != len(self.labels) or not set(self.labels) <= CLASSES:
            raise ValueError('분류기 클래스가 올바르지 않습니다.')
        self.weights = np.asarray(data['coefficients'], dtype=np.float64)
        self.intercepts = np.asarray(data['intercepts'], dtype=np.float64)
        rows = 1 if len(self.labels) == 2 else len(self.labels)
        if self.weights.shape != (rows, 768) or self.intercepts.shape != (rows,):
            raise ValueError('분류기 계수의 크기가 올바르지 않습니다.')
        if not np.isfinite(self.weights).all() or not np.isfinite(self.intercepts).all():
            raise ValueError('분류기 계수는 유한한 숫자여야 합니다.')
        self.threshold = float(data.get('abstain_threshold', .6))
        if not np.isfinite(self.threshold) or not .5 <= self.threshold <= 1:
            raise ValueError('판정 보류 임계값이 올바르지 않습니다.')

    def predict(self, features):
        vector = np.asarray(features, dtype=np.float64)
        norm = np.linalg.norm(vector)
        if vector.shape != (768,) or not np.isfinite(vector).all() or not np.isfinite(norm) or norm < 1e-12:
            raise ValueError('유효한 DINOv3 768차원 특징이 필요합니다.')
        logits = self.weights @ (vector / norm) + self.intercepts
        if len(self.labels) == 2:
            positive = 1 / (1 + np.exp(-np.clip(logits[0], -700, 700)))
            probabilities = np.array([1 - positive, positive])
        else:
            scores = np.exp(logits - logits.max())
            probabilities = scores / scores.sum()
        index = int(probabilities.argmax())
        score = float(probabilities[index])
        return {'status': 'predicted' if score >= self.threshold else 'abstained',
                'label': self.labels[index] if score >= self.threshold else None,
                'candidate_label': self.labels[index],
                'model_score': round(score, 5), 'experimental': True,
                'probabilities': {label: round(float(value), 5) for label, value in zip(self.labels, probabilities)},
                'note': '사진상 윤곽 가시성의 실험적 분류이며 근육량·근력·의학적 등급이 아닙니다. 모델 점수는 정확도를 보장하지 않습니다.'}
