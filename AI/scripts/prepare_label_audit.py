"""Prepare a blinded consistency audit; never change original human labels."""
import argparse
import hashlib
import json
from pathlib import Path
import random
import shutil
import sys
import tempfile
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.dataset import AnnotationStore, write_json, LABELS
from training.reviewed_crops import validate_release


def private_path(path):
    path = Path(path).resolve()
    if not path.is_relative_to(ROOT/'.runtime') or any(x.startswith('quarantine_web_') for x in path.parts):
        raise ValueError('격리되지 않은 AI/.runtime 자료만 허용합니다.')
    return path


def source_credits(entry):
    """Carry attribution forward without exposing previous grades or review opinions."""
    for path in sorted((ROOT/'.runtime').glob('*/source-licenses.json')):
        if any(p.startswith('quarantine_web_') for p in path.parts):
            continue
        records = json.loads(path.read_text())
        if not isinstance(records, list):
            continue
        for record in records:
            if record.get('source_sha256',record.get('sha256')) != entry.get('source_sha256'):
                continue
            url=record.get('source_url',record.get('source_page',''))
            credits=[{'label':'사진 출처·개별 이용 조건','url':url}]
            if record.get('license_url'):
                credits.append({'label':record.get('license','라이선스'),'url':record['license_url']})
            credit=record.get('author',record.get('attribution','개별 저작자 표기는 출처 페이지 참조'))
            return {'status':'needs_review','reason':f'이전 등급을 숨긴 기준 재검수입니다. {credit}. 표시용 축소·상완 크롭을 적용했습니다. 원래 라벨은 자동 변경하지 않습니다.',
                    'credits':credits,'human_confirmation_required':True}
    return {'status':'needs_review','reason':'이전 등급을 숨긴 기준 재검수입니다. 원래 라벨은 자동 변경하지 않습니다. 기존 로컬 자료의 이용 조건은 해당 출처 기록을 참조하세요.',
            'human_confirmation_required':True}


def prepare(source, output, per_class=3):
    source, output = private_path(source), private_path(output)
    if output.exists() or not 1 <= per_class <= 10:
        raise ValueError('새 출력 폴더와 등급당 1~10개를 지정하세요.')
    store = AnnotationStore(source)
    if store.dataset.get('purpose', 'training') != 'training':
        raise ValueError('학습 검수 자료의 라벨만 재검수합니다.')
    validate_release(store)
    source_sha = hashlib.sha256(store.path.read_bytes()).hexdigest()
    rng = random.Random(42)
    selected, used = [], set()
    for label in LABELS:
        candidates = [(key, entry, store.annotations[key]) for key, entry in store.entries.items()
                      if key in store.annotations and store.annotations[key].get('reviewed') is True
                      and store.annotations[key].get('label') == label and entry.get('review_hashes')]
        rng.shuffle(candidates)
        chosen = []
        for row in candidates:
            if row[2]['subject_id'] not in used:
                chosen.append(row)
                used.add(row[2]['subject_id'])
            if len(chosen) == per_class:
                break
        if len(chosen) != per_class:
            raise ValueError('등급별 검수 증거가 있는 서로 다른 인물이 부족합니다.')
        selected += chosen
    rng.shuffle(selected)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.label-audit-', dir=output.parent) as tmp:
        staging = Path(tmp)
        entries, reference, screening = [], {}, {}
        for index, (old_key, entry, annotation) in enumerate(selected, 1):
            key = f'audit_{index:02}'
            value = dict(entry, id=key, image_name=f'기준확인_{index:02}',
                         subject_hint=f'audit_person{index:02}', split_hint='test')
            for kind in ('image', 'crop', 'features'):
                relative = kind+'/'+key+store.asset(old_key,kind).suffix
                (staging/relative).parent.mkdir(exist_ok=True)
                shutil.copy2(store.asset(old_key, kind), staging/relative)
                value[kind] = relative
            # Keep previous label and original IDs out of dataset and public labeling API.
            for field in ('source_dataset','source_entry_id'):
                value.pop(field, None)
            entries.append(value)
            screening[key] = source_credits(entry)
            reference[key] = {'source_entry_id': old_key, 'previous_label': annotation['label']}
        write_json(staging/'dataset.json', {'schema_version':1,'purpose':'label_audit',
                    'review_release':'source_and_crop_hash_v1','entries':entries,'failures':[]})
        write_json(staging/'audit-reference.json', {'source_directory':str(source),
                    'source_annotation_sha256':source_sha,'entries':reference,
                    'purpose':'annotation consistency only; not model evaluation'})
        write_json(staging/'pre_screening.json', screening)
        if hashlib.sha256(store.path.read_bytes()).hexdigest()!=source_sha:
            raise ValueError('준비 중 원본 라벨이 변경됐습니다.')
        if output.exists():
            raise ValueError('출력 폴더가 이미 생성됐습니다.')
        staging.rename(output)
    return len(entries)


if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--dataset',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--per-class',type=int,default=3)
    args=p.parse_args()
    try: print('정답을 숨긴 재검수 항목:',prepare(args.dataset,args.output,args.per_class))
    except (OSError,ValueError) as exc: raise SystemExit(str(exc))
