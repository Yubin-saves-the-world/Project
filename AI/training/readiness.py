"""Report missing human data without relaxing training/evaluation requirements."""
from collections import Counter, defaultdict
from .dataset import AnnotationStore, LABELS, SPLITS


def readiness(directory):
    store = AnnotationStore(directory)
    counts, subjects = Counter(), defaultdict(set)
    per_split = {split: {label: set() for label in LABELS} for split in SPLITS}
    pending = excluded = 0
    for key in store.entries:
        row = store.annotations.get(key)
        if not row or row.get('reviewed') is not True:
            pending += 1
            continue
        label = row.get('label')
        if label == 'exclude':
            excluded += 1
            continue
        if label not in LABELS or row.get('split') not in SPLITS or not row.get('subject_id'):
            raise ValueError('잘못된 검수 라벨입니다.')
        counts[label] += 1
        subjects[label].add(row['subject_id'])
        per_split[row['split']][label].add(row['subject_id'])
    active = sorted(counts)
    holdout_missing = {split: {label: max(0, (2 if split == 'train' else 1)-len(per_split[split][label]))
                               for label in active} for split in SPLITS}
    cv_missing = {label: max(0, 3-len(subjects[label])) for label in active}
    valid = sum(counts.values())
    return {'dataset_name': store.directory.name, 'batch_id': store.batch_id,
            'total': len(store.entries), 'pending': pending, 'excluded': excluded,
            'usable_regions': valid, 'distinct_subjects': len(set().union(*subjects.values())) if subjects else 0,
            'labels': {label: {'regions': counts[label], 'subjects': len(subjects[label])} for label in LABELS},
            'split_subject_counts': {split: {label: len(values) for label, values in rows.items()}
                                     for split, rows in per_split.items()},
            'minimum_missing_subjects': {'holdout': holdout_missing, 'grouped_cv': cv_missing},
            'holdout_minimum_counts_met': len(active) >= 2 and not any(n for rows in holdout_missing.values() for n in rows.values()),
            'grouped_cv_minimum_counts_met': len(active) >= 2 and not any(cv_missing.values()),
            'weak_class_missing': counts['weak'] == 0,
            'note': '최소 개수 충족은 실행 준비 조건일 뿐입니다. 특징·중복·인물 분할 검사는 학습 명령에서 별도로 수행합니다.',
            'limitations': ['같은 사진의 양팔은 서로 독립된 사람이 아닙니다.',
                           '등급별 성별·의복·조명·촬영 방향의 대표성은 사람이 별도로 검토해야 합니다.',
                           '사진상 윤곽 라벨이며 근육량·근력 정답 데이터가 아닙니다.']}
