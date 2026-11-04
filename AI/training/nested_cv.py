"""Tune regularization inside subject-disjoint folds; never deploy automatically."""
from pathlib import Path
import hashlib
import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import LeaveOneGroupOut, StratifiedGroupKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import Normalizer
from sklearn.metrics import accuracy_score, f1_score, confusion_matrix

from analyzers.dinov3_features import MODEL_ID, MODEL_REVISION
from .dataset import SCHEMA, write_json
from .grouped_cv import train_grouped_cv
from .train import read_training_data

CANDIDATES = (1., 10., 100.)
THRESHOLD = .6


def estimator(c):
    return make_pipeline(Normalizer(), LogisticRegression(
        C=c, class_weight='balanced', max_iter=2000, random_state=42))


def choose_regularization(x, y, subjects, classes):
    """Inner held-out people select C; outer evaluation data never enter here."""
    folds = list(LeaveOneGroupOut().split(x, y, subjects))
    if not folds or any(set(y[train]) != set(classes) for train, _ in folds):
        raise ValueError('내부 검증에서 인물을 제외한 뒤에도 모든 등급이 학습에 남아야 합니다.')
    results = []
    for c in CANDIDATES:
        predicted = np.empty(len(y), dtype=object)
        for train, validation in folds:
            model = estimator(c)
            model.fit(x[train], y[train])
            predicted[validation] = model.predict(x[validation])
        results.append({'C': c, 'inner_macro_f1': float(f1_score(
            y, predicted, labels=classes, average='macro', zero_division=0))})
    # Candidates are ordered conservatively: equal scores keep the smaller C.
    selected = max(results, key=lambda row: row['inner_macro_f1'])['C']
    plan = [{'train_subjects': sorted(set(subjects[train])),
             'validation_subjects': sorted(set(subjects[validation]))} for train, validation in folds]
    return selected, results, plan


def metrics(y, prediction, scores, classes):
    accepted = scores >= THRESHOLD
    return {'accuracy': float(accuracy_score(y, prediction)),
            'macro_f1': float(f1_score(y, prediction, labels=classes, average='macro', zero_division=0)),
            'confusion_matrix': confusion_matrix(y, prediction, labels=classes).tolist(),
            'accepted_count': int(accepted.sum()), 'accepted_coverage': float(accepted.mean()),
            'accepted_accuracy': float(accuracy_score(y[accepted], prediction[accepted])) if accepted.any() else None}


def benchmark_nested(directory):
    directory = Path(directory).resolve()
    if any(part.startswith('quarantine_web_') for part in directory.parts):
        raise ValueError('격리된 자료는 실험할 수 없습니다.')
    validation = train_grouped_cv(directory, validate_only=True)
    grouped, classes, review = read_training_data(directory, enforce_holdout=False)
    rows = [row for split in ('train', 'val', 'test') for row in grouped[split]]
    x = np.stack([row[0] for row in rows])
    y = np.asarray([row[1] for row in rows])
    subjects = np.asarray([row[2] for row in rows])
    folds = StratifiedGroupKFold(n_splits=3, shuffle=True, random_state=validation['seed'])
    predictions = {name: np.empty(len(y), dtype=object) for name in ('fixed_C1', 'nested_tuned')}
    scores = {name: np.zeros(len(y)) for name in predictions}
    plans = []
    for train, test in folds.split(x, y, subjects):
        selected, candidates, inner_plan = choose_regularization(x[train], y[train], subjects[train], classes)
        plans.append({'train_subjects': sorted(set(subjects[train])),
                      'held_out_subjects': sorted(set(subjects[test])),
                      'selected_C': selected, 'inner_candidates': candidates, 'inner_folds': inner_plan})
        for name, c in (('fixed_C1', 1.), ('nested_tuned', selected)):
            model = estimator(c)
            model.fit(x[train], y[train])
            predictions[name][test] = model.predict(x[test])
            scores[name][test] = model.predict_proba(x[test]).max(axis=1)
    selected, candidates, final_plan = choose_regularization(x, y, subjects, classes)
    final = estimator(selected)
    final.fit(x, y)
    classifier = final.steps[-1][1]
    artifact = {'schema_version': 1, 'task': 'upper_arm_contour_visibility', 'feature_schema': SCHEMA,
                'model_id': MODEL_ID, 'model_revision': MODEL_REVISION, 'classes': classifier.classes_.tolist(),
                'coefficients': classifier.coef_.tolist(), 'intercepts': classifier.intercept_.tolist(),
                'abstain_threshold': THRESHOLD, 'experimental': True}
    report = {'protocol': '3 outer subject-disjoint folds; inner leave-one-subject-out selects C',
              'independent_test': False, 'samples': len(y), 'subjects': len(set(subjects)),
              'classes': classes, 'threshold': THRESHOLD, 'candidate_C': list(CANDIDATES),
              'selection_metric': 'pooled inner macro-F1, smaller C wins ties',
              'evaluation': {name: metrics(y, predictions[name], scores[name], classes) for name in predictions},
              'folds': plans, 'final_selected_C': selected, 'final_inner_candidates': candidates,
              'final_inner_folds': final_plan, 'review_counts': review,
              'data_fingerprint': hashlib.sha256(x.tobytes()+y.tobytes()+subjects.tobytes()).hexdigest(),
              'deployed_model_changed': False,
              'limitations': ['Repeated experiments on this small dataset do not establish independent test performance.',
                             'Model scores are uncalibrated; higher accepted coverage alone is not improved accuracy.',
                             'Candidate model is experimental and is not activated automatically.']}
    write_json(directory / 'nested-candidate-model.json', artifact)
    write_json(directory / 'nested-benchmark-report.json', report)
    return report
