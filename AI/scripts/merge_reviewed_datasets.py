"""Namespace user-confirmed independent subject IDs, preserving all labels/splits."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.dataset import AnnotationStore, write_json
from training.reviewed_crops import validate_release

SOURCES = {'local': 'contour_dataset', 'safev2': 'reviewed_arm_batch_v2'}

def merge(destination, source_names=None):
    destination = Path(destination).resolve()
    if not destination.is_relative_to(ROOT / '.runtime') or any(p.startswith('quarantine_web_') for p in destination.parts):
        raise ValueError('통합 자료는 AI/.runtime 안에만 저장합니다.')
    if destination.exists():
        raise ValueError('기존 통합 데이터셋은 덮어쓰지 않습니다.')
    # Read and validate inputs before creating outputs. Inputs are never written.
    names = SOURCES if source_names is None else source_names
    if not names:
        raise ValueError('통합할 검수 자료가 필요합니다.')
    sources = []
    for prefix, name in names.items():
        if not re.fullmatch(r'[A-Za-z0-9_]{1,20}', prefix):
            raise ValueError('자료 묶음 이름은 영문·숫자·밑줄 1~20자입니다.')
        path = (ROOT / '.runtime' / name).resolve()
        if not path.is_relative_to(ROOT / '.runtime') or any(p.startswith('quarantine_web_') for p in path.parts):
            raise ValueError('격리되지 않은 AI/.runtime 검수 자료만 통합합니다.')
        store = AnnotationStore(path)
        if store.dataset.get('purpose') in {'independent_test','label_audit'}:
            raise ValueError('독립 시험·라벨 재검수 자료를 학습 묶음에 통합할 수 없습니다.')
        validate_release(store)
        if not store.path.is_file() or not store.entries:
            raise ValueError('입력 항목의 실제 검수 저장이 필요합니다: ' + prefix)
        sources.append((prefix, store))
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

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / '.runtime/merged_reviewed_dataset')
    parser.add_argument('--include', action='append', default=[], metavar='NAME=DIRECTORY',
                        help='기본 검수 자료에 추가할 실제 라벨 저장 데이터셋. 경로는 AI/.runtime 기준')
    args = parser.parse_args()
    names = dict(SOURCES)
    for value in args.include:
        if '=' not in value:
            parser.error('--include는 NAME=DIRECTORY 형식입니다.')
        prefix, path = value.split('=', 1)
        if prefix in names:
            parser.error('중복 자료 묶음 이름입니다.')
        names[prefix] = path
    print('통합 검수 항목:', merge(args.output, names))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit(str(exc))
