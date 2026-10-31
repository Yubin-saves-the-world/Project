"""Spring-facing photo analysis. DINOv3 features are not muscle grades."""
from __future__ import annotations
import base64
import math
import os
import threading
import time
from pathlib import Path
import cv2
import numpy as np
from PIL import Image
from analyzers.analyze_body import analyze_image
from analyzers.dinov3_features import DinoFeatureExtractor, upper_arm_box
from analyzers.contour_classifier import ContourClassifier

class AnalysisFailure(ValueError):
    def __init__(self, code, message):
        self.code, self.message = code, message
        super().__init__(message)

def rounded_measure(value):
    """Missing or degenerate ratios stay unavailable instead of failing JSON output."""
    if value is None:
        return None
    value = float(value)
    return round(value, 2) if math.isfinite(value) else None


def valid_landmark(point):
    return (point is not None
            and all(isinstance(point.get(k), (int, float))
                    and math.isfinite(point[k]) for k in ('x', 'y', 'visibility'))
            and point['visibility'] >= .5
            and 0 <= point['x'] <= 1 and 0 <= point['y'] <= 1)


class AnalysisEngine:
    def __init__(self, model_path, device='cpu'):
        self.lock = threading.Lock()
        self.dino = DinoFeatureExtractor(model_path, device=device, local_only=Path(model_path).exists())
        classifier_path = os.environ.get('AI_CONTOUR_MODEL')
        self.contour = ContourClassifier(classifier_path) if classifier_path else None

    def analyze(self, image_path, output_dir):
        # Serial inference bounds memory and protects MediaPipe/PyTorch shared state.
        with self.lock:
            started = time.perf_counter()
            image = cv2.imread(str(image_path))
            if image is None:
                raise AnalysisFailure('INVALID_IMAGE', 'JPG 또는 PNG 사진을 보내 주세요.')
            blur = float(cv2.Laplacian(cv2.cvtColor(image, cv2.COLOR_BGR2GRAY), cv2.CV_64F).var())
            if blur < 5:
                raise AnalysisFailure('IMAGE_BLURRY', '사진이 흐리거나 단색이에요. 다시 촬영해 주세요.')
            try:
                _, debug, result = analyze_image(str(image_path), str(output_dir), .5)
            except RuntimeError as exc:
                if 'No body pose' in str(exc):
                    raise AnalysisFailure('NO_PERSON', '사람을 찾지 못했어요. 전신 사진을 사용해 주세요.') from exc
                raise
            lm = result['landmarks']
            required = ['nose','left_shoulder','right_shoulder','left_hip','right_hip','left_ankle','right_ankle']
            if any(not valid_landmark(lm.get(k)) for k in required):
                raise AnalysisFailure('NOT_FULL_BODY', '머리부터 발목까지 보이는 사진으로 다시 촬영해 주세요.')
            metrics = result['metrics']
            measures = { 'shoulder_tilt_deg': rounded_measure(abs(metrics['shoulder_tilt_deg'])),
                         'pelvis_tilt_deg': rounded_measure(abs(metrics['hip_tilt_deg'])),
                         'neck_forward_deg': None,
                         'shoulder_hip_ratio': rounded_measure(metrics['shoulder_to_hip_ratio']),
                         'torso_leg_ratio': rounded_measure(metrics['torso_leg_ratio']),
                         'unavailable': [{'key':'neck_forward_deg','reason':'SIDE_ANALYSIS_NOT_IMPLEMENTED'}] }
            features = []
            with Image.open(image_path) as pil:
                for side in ('left','right'):
                    box = upper_arm_box(lm, side, *pil.size)
                    if box is None:
                        features.append({'part': f'{side}_upper_arm','status':'unavailable','reason':'LOW_CONFIDENCE'})
                        continue
                    values, elapsed = self.dino.extract(pil.crop(box).convert('RGB'))
                    if any(not np.isfinite(v).all() for v in values.values()):
                        raise RuntimeError('Non-finite DINOv3 features')
                    features.append({'part':f'{side}_upper_arm', 'status':'extracted',
                                     'classification':'not_trained','crop_box':list(box),
                                     'cls':values['cls'].tolist(), 'patch_mean':values['patch_mean'].tolist(),
                                     'patch_shape':list(values['patches'].shape), 'seconds':round(elapsed,4)})
            if self.contour is not None:
                for part in features:
                    if part['status'] == 'extracted':
                        part['contour'] = self.contour.predict(part['cls'] + part['patch_mean'])
                        part['classification'] = 'contour_' + part['contour']['status']
            labels = {'shoulder_tilt_deg':'어깨 기울기','pelvis_tilt_deg':'골반 기울기',
                      'neck_forward_deg':'목 전방 각도','shoulder_hip_ratio':'어깨/골반 비율','torso_leg_ratio':'상체/하체 비율'}
            return {'status':'done','measurement_version':'pixel-dino-v1','measures':measures,
                    'balance_score':None,'body_type':None,
                    'judgements':[{'item':k,'label':label,'value':measures[k],
                                   'unit':'deg' if k.endswith('_deg') else 'ratio',
                                   'level':'unavailable','reason':'PROFILE_NOT_VALIDATED'} for k,label in labels.items()],
                    'goal_comparison':None,'text_summary':None,
                    'summary':f"사진상 어깨선 약 {measures['shoulder_tilt_deg']}도, 골반 추정점 연결선 약 {measures['pelvis_tilt_deg']}도입니다.",
                    'dinov3':{'model':'facebook/dinov3-vits16-pretrain-lvd1689m','revision':self.dino.revision,
                               'device':self.dino.device,'parts':features},
                    'warnings':['사진 기반 참고 수치이며 의료적 진단이 아닙니다.',
                                '의복과 가림은 자동 판정하지 못합니다. 특징 추출을 근육 등급으로 해석하지 마세요.',
                                '다중 인물 및 정면 여부 자동 검사는 아직 구현하지 않았습니다.'],
                    'processing_seconds':round(time.perf_counter()-started,3),
                    'debug_image_base64':base64.b64encode(Path(debug).read_bytes()).decode()}
