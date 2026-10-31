"""Human-reviewed subject-separated training; validation selects C, test stays held out."""
from collections import Counter
import hashlib
import json
from pathlib import Path

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, classification_report
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import Normalizer

from analyzers.dinov3_features import MODEL_ID, MODEL_REVISION
from .dataset import AnnotationStore, DIMENSION, LABELS, SCHEMA, SPLITS, write_json


def read_training_data(directory, enforce_holdout=True):
    store = AnnotationStore(directory)
    grouped = {split: [] for split in SPLITS}
    subject_splits, image_subjects, image_splits, feature_splits = {}, {}, {}, {}
    pending, excluded = 0, 0
    for key, entry in store.entries.items():
        annotation = store.annotations.get(key)
        if not annotation or annotation.get('reviewed') is not True:
            pending += 1
            continue
        subject, split, label = annotation.get('subject_id'), annotation.get('split'), annotation.get('label')
        if not subject or split not in SPLITS or label not in (*LABELS, 'exclude'):
            raise ValueError('검수 라벨의 필수 값이 잘못됐습니다.')
        if subject_splits.setdefault(subject, split) != split:
            raise ValueError('동일 인물이 여러 데이터 구분에 섞였습니다.')
        image_hash = entry['source_sha256']
        if image_subjects.setdefault(image_hash, subject) != subject:
            raise ValueError('같은 원본 사진의 인물 ID가 서로 다릅니다.')
        if image_splits.setdefault(image_hash, split) != split:
            raise ValueError('동일 원본 사진이 학습·평가에 중복됐습니다.')
        if label == 'exclude':
            if not annotation.get('reason'):
                raise ValueError('제외 이유가 필요합니다.')
            excluded += 1
            continue
        if entry.get('feature_schema') != SCHEMA or entry.get('model_revision') != MODEL_REVISION:
            raise ValueError('모델 리비전이나 특징 버전이 다른 데이터가 있습니다.')
        with np.load(store.asset(key, 'features'), allow_pickle=False) as archive:
            vector = np.asarray(archive['vector'], dtype=np.float64)
        if vector.shape != (DIMENSION,) or not np.isfinite(vector).all() or np.linalg.norm(vector) < 1e-12:
            raise ValueError('유효하지 않은 특징 벡터입니다.')
        feature_hash = hashlib.sha256(vector.tobytes()).hexdigest()
        if feature_splits.setdefault(feature_hash, split) != split:
            raise ValueError('동일 특징이 학습·평가에 중복됐습니다.')
        grouped[split].append((vector, label, subject))
    classes = sorted({label for rows in grouped.values() for _, label, _ in rows})
    if len(classes) < 2:
        raise ValueError('학습에는 사람이 검수한 라벨 2종류 이상이 필요합니다. 라벨링 화면에서 먼저 저장하세요.')
    for split in SPLITS if enforce_holdout else ():
        counts = {label: len({subject for _, value, subject in grouped[split] if value == label}) for label in classes}
        minimum = 2 if split == 'train' else 1
        if any(count < minimum for count in counts.values()):
            raise ValueError(f'{split}: 클래스별 서로 다른 인물이 최소 {minimum}명 필요합니다. 현재 인물 수: {counts}')
    return grouped, classes, {'pending': pending, 'excluded': excluded}


def evaluate(model, rows, labels, threshold=.6):
    x = np.stack([row[0] for row in rows])
    y = [row[1] for row in rows]
    predicted = model.predict(x)
    accepted = model.predict_proba(x).max(axis=1) >= threshold
    return {'samples': len(rows), 'subjects': len({row[2] for row in rows}),
            'label_counts': dict(Counter(y)), 'accuracy': float(accuracy_score(y, predicted)),
            'macro_f1': float(f1_score(y, predicted, labels=labels, average='macro', zero_division=0)),
            'confusion_matrix': confusion_matrix(y, predicted, labels=labels).tolist(),
            'per_class': {label: values for label, values in classification_report(y, predicted, labels=labels, output_dict=True, zero_division=0).items() if label in labels},
            'accepted_coverage': float(accepted.mean()),
            'accepted_accuracy': float(accuracy_score(np.asarray(y)[accepted], predicted[accepted])) if accepted.any() else None}


def train(directory, threshold=.6):
    if not .5 <= threshold <= 1:
        raise ValueError('판정 보류 임계값은 0.5~1 사이여야 합니다.')
    grouped, classes, counts = read_training_data(directory)
    x = np.stack([row[0] for row in grouped['train']])
    y = [row[1] for row in grouped['train']]
    best, best_score, selected_c = None, -1, None
    candidates = []
    for c in (.01, .1, 1., 10.):
        model = make_pipeline(Normalizer(), LogisticRegression(C=c, class_weight='balanced', max_iter=2000, random_state=42))
        model.fit(x, y)
        score = evaluate(model, grouped['val'], classes)['macro_f1']
        candidates.append({'C': c, 'validation_macro_f1': score})
        if score > best_score:
            best, best_score, selected_c = model, score, c
    evaluations = {split: evaluate(best, rows, classes, threshold) for split, rows in grouped.items()}
    classifier = best.steps[-1][1]
    artifact = {'schema_version': 1, 'task': 'upper_arm_contour_visibility', 'feature_schema': SCHEMA,
                'model_id': MODEL_ID, 'model_revision': MODEL_REVISION, 'classes': classifier.classes_.tolist(),
                'coefficients': classifier.coef_.tolist(), 'intercepts': classifier.intercept_.tolist(),
                'abstain_threshold': threshold, 'experimental': True}
    report = {'status': 'trained_experimental', 'task': artifact['task'], 'classes': classes,
              'selected_C': selected_c, 'validation_candidates': candidates, 'evaluation': evaluations,
              'review_counts': counts, 'test_used_for_training_or_selection': False,
              'training_majority_class': Counter(y).most_common(1)[0][0],
              'test_majority_baseline_accuracy': sum(row[1] == Counter(y).most_common(1)[0][0] for row in grouped['test']) / len(grouped['test']),
              'note': '윤곽 가시성 라벨만 학습합니다. 테스트 정확도는 이 데이터셋 범위이며 실사용 정확도나 임상 타당성을 보장하지 않습니다.'}
    directory = Path(directory)
    write_json(directory / 'model.json', artifact)
    write_json(directory / 'training-report.json', report)
    return artifact, report, best
