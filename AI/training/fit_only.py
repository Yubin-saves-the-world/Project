"""Explicit final fit for a small dataset; never claims held-out performance."""
from collections import Counter
import hashlib
from pathlib import Path
import tempfile

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import Normalizer

from analyzers.dinov3_features import MODEL_ID, MODEL_REVISION
from .dataset import SCHEMA, write_json
from .train import read_training_data


def fit_only(directory, output):
    directory, output = Path(directory).resolve(), Path(output).resolve()
    if output.exists():
        raise ValueError('기존 모델·출력은 덮어쓰지 않습니다. 새 출력 폴더를 지정하세요.')
    annotation = directory / 'annotations.json'
    before = hashlib.sha256(annotation.read_bytes()).hexdigest()
    dataset_before = hashlib.sha256((directory/'dataset.json').read_bytes()).hexdigest()
    grouped, classes, counts = read_training_data(directory, enforce_holdout=False)
    if counts['pending']:
        raise ValueError('모든 후보의 검수 저장을 먼저 완료하세요.')
    rows = [row for split in ('train', 'val', 'test') for row in grouped[split]]
    x = np.stack([row[0] for row in rows])
    y = np.array([row[1] for row in rows])
    model = make_pipeline(Normalizer(), LogisticRegression(
        C=1, class_weight='balanced', max_iter=2000, random_state=42))
    model.fit(x, y)
    if (hashlib.sha256(annotation.read_bytes()).hexdigest() != before
            or hashlib.sha256((directory/'dataset.json').read_bytes()).hexdigest() != dataset_before):
        raise ValueError('학습 중 라벨이 변경됐습니다. 다시 실행하세요.')
    classifier = model.steps[-1][1]
    artifact = {
        'schema_version': 1, 'task': 'upper_arm_contour_visibility',
        'feature_schema': SCHEMA, 'model_id': MODEL_ID, 'model_revision': MODEL_REVISION,
        'classes': classifier.classes_.tolist(), 'coefficients': classifier.coef_.tolist(),
        'intercepts': classifier.intercept_.tolist(), 'abstain_threshold': .6,
        'experimental': True, 'validation_status': 'not_evaluated',
        'training_samples': len(rows), 'annotation_sha256': before,
        'training_dataset_sha256': dataset_before,
    }
    report = {
        'status': 'trained_unvalidated', 'protocol': 'fit-only; all usable reviewed rows',
        'samples': len(rows), 'label_counts': dict(Counter(y)),
        'subject_groups': len({row[2] for row in rows}), 'identity_verification': 'not_automated',
        'review_counts': counts, 'independent_test': False, 'evaluation': None,
        'consumed_splits': {split: len(values) for split, values in grouped.items()},
        'annotation_sha256': before,
        'limitations': ['All supplied splits were used for fitting; none remains a held-out test.',
                        'No accuracy or clinical validity is claimed. Obtain new independent evaluation data.',
                        'Contour visibility is not muscle mass, strength or a health score.'],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent, prefix='.fit-only-') as temporary:
        staging = Path(temporary) / 'result'
        staging.mkdir()
        write_json(staging / 'model.json', artifact)
        write_json(staging / 'training-report.json', report)
        staging.rename(output)
    return report
