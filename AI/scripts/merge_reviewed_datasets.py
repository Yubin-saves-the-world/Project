"""Namespace user-confirmed independent subject IDs, preserving all labels/splits."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.dataset import AnnotationStore, write_json

SOURCES = {'local': 'contour_dataset', 'safev2': 'reviewed_arm_batch_v2'}

def merge(destination):
    destination = Path(destination).resolve()
    if not destination.is_relative_to(ROOT / '.runtime'):
        raise ValueError('통합 자료는 AI/.runtime 안에만 저장합니다.')
    if destination.exists():
        raise ValueError('기존 통합 데이터셋은 덮어쓰지 않습니다.')
    # Read and validate inputs before creating outputs. Inputs are never written.
    sources = [(prefix, AnnotationStore(ROOT / '.runtime' / name)) for prefix, name in SOURCES.items()]
    image_owners = {}
    entries, annotations, mapping, fingerprints = [], {}, {}, {}
    for prefix, store in sources:
        fingerprints[prefix] = hashlib.sha256(store.path.read_bytes()).hexdigest()
        for key, entry in store.entries.items():
            a = store.annotations.get(key)
            if not a or a.get('reviewed') is not True:
                raise ValueError('모든 입력 항목의 검수 저장이 필요합니다.')
            subject = prefix + '_' + a['subject_id']
            if len(subject) > 64:
                raise ValueError('통합 인물 ID가 64자를 초과합니다.')
            previous = image_owners.setdefault(entry['source_sha256'], subject)
            if previous != subject:
                raise ValueError('묶음 간 동일 원본 사진이 있습니다. 인물 매핑을 확인하세요.')
            merged = dict(entry, id=prefix + '_' + key, source_dataset=prefix, source_entry_id=key)
            for kind in ('image', 'crop', 'features'):
                # asset() checks path containment and file existence.
                store.asset(key, kind)
                merged[kind] = prefix + '/' + entry[kind]
            entries.append(merged)
            annotations[merged['id']] = dict(a, subject_id=subject)
            mapping[prefix + '/' + a['subject_id']] = subject
    destination.mkdir(parents=True)
    for prefix, store in sources:
        for key, entry in store.entries.items():
            for kind in ('image', 'crop', 'features'):
                target = destination / prefix / entry[kind]
                target.parent.mkdir(parents=True, exist_ok=True)
                if not target.exists():
                    shutil.copy2(store.asset(key, kind), target)
    write_json(destination / 'dataset.json', {'schema_version': 1, 'entries': entries,
               'failures': [], 'input_images': len(image_owners), 'duplicates': 0})
    write_json(destination / 'annotations.json', annotations)
    write_json(destination / 'merge-provenance.json', {'subject_mapping': mapping,
               'source_annotation_sha256': fingerprints, 'labels_changed': False, 'splits_changed': False,
               'identity_basis': 'User confirmed subject IDs restart independently in each dataset.'})
    for prefix, store in sources:
        if hashlib.sha256(store.path.read_bytes()).hexdigest() != fingerprints[prefix]:
            raise RuntimeError('입력 라벨이 작업 중 변경됐습니다. 통합 자료를 다시 검수하세요.')
    return len(entries)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / '.runtime/merged_reviewed_dataset')
    args = parser.parse_args()
    print('통합 검수 항목:', merge(args.output))
