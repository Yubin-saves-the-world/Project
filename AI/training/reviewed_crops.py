"""Prepare exact, visually reviewed arm crops without inventing human labels."""
import hashlib
import json
from pathlib import Path
import tempfile
import numpy as np
from PIL import Image
from analyzers.dinov3_features import DinoFeatureExtractor, MODEL_REVISION
from .dataset import normalize_image, feature_vector, write_json, SCHEMA

ROOT = Path(__file__).resolve().parents[1]
REVIEW_RELEASE = 'source_and_crop_hash_v1'


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def prepare(manifest_path, output):
    manifest_path, output = Path(manifest_path).resolve(), Path(output).resolve()
    runtime = (ROOT/'.runtime').resolve()
    for path in (manifest_path, output):
        if not path.is_relative_to(runtime) or any(p.startswith('quarantine_web_') for p in path.parts):
            raise ValueError('격리되지 않은 AI/.runtime 자료만 사용합니다.')
    if output.exists():
        raise ValueError('기존 검수 자료는 덮어쓰지 않습니다.')
    rows = json.loads(manifest_path.read_text())['entries']
    if not 1 <= len(rows) <= 200:
        raise ValueError('검수 후보는 1~200개로 준비하세요.')
    approved = []
    seen = set()
    for row in rows:
        if not all(row.get(key) is True for key in ('original_visually_reviewed', 'crop_visually_reviewed',
                                                    'skin_visible_confirmed', 'upper_arm_location_confirmed')):
            raise ValueError('원본·크롭·피부·상완 위치의 명시적인 검수가 필요합니다.')
        if not row.get('reviewer') or not row.get('review_reason'):
            raise ValueError('검수자와 확인 내용을 기록하세요.')
        source, crop = [(manifest_path.parent/row[key]).resolve() for key in ('file', 'crop_file')]
        if any(not p.is_relative_to(manifest_path.parent) or any(part.startswith('quarantine_web_') for part in p.parts) for p in (source, crop)):
            raise ValueError('검수 파일 경로가 자료 폴더를 벗어났습니다.')
        if digest(source) != row['source_sha256'] or digest(crop) != row['crop_sha256']:
            raise ValueError('검수한 파일이 변경됐습니다.')
        if row['crop_sha256'] in seen:
            raise ValueError('같은 크롭을 중복 등록할 수 없습니다.')
        seen.add(row['crop_sha256'])
        image = normalize_image(source)
        box = row['normalized_box']
        if (len(box) != 4 or any(type(v) is not int for v in box)
                or not (0 <= box[0] < box[2] <= image.width and 0 <= box[1] < box[3] <= image.height)
                or list(image.size) != row['normalized_image_size']):
            raise ValueError('정규화된 원본과 크롭 좌표가 일치하지 않습니다.')
        with Image.open(crop) as preview:
            if preview.format != 'PNG':
                raise ValueError('검수 크롭은 원본 픽셀 대응을 확인할 수 있는 PNG여야 합니다.')
            pixels = preview.convert('RGB').copy()
        if min(pixels.size) < 64 or max(pixels.size) < 128:
            raise ValueError('검수 크롭은 짧은 축 64px·긴 축 128px 이상이어야 합니다.')
        expected = image.crop(box)
        if pixels.size != expected.size or not np.array_equal(np.asarray(pixels), np.asarray(expected)):
            raise ValueError('크롭이 지정한 원본 영역의 픽셀과 일치하지 않습니다.')
        approved.append((row, image, pixels))
    model_path = json.loads((runtime/'model.json').read_text())['path']
    dino = DinoFeatureExtractor(model_path, device='cpu', local_only=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.reviewed-crops-', dir=output.parent) as directory:
        staging = Path(directory)
        for name in ('images', 'crops', 'features'):
            (staging/name).mkdir()
        entries = []
        for row, image, pixels in approved:
            key = hashlib.sha256((row['source_sha256']+row['crop_sha256']+MODEL_REVISION).encode()).hexdigest()[:24]
            image_rel = 'images/'+row['source_sha256']+'.jpg'
            crop_rel, feature_rel = f'crops/{key}.png', f'features/{key}.npz'
            image.save(staging/image_rel, quality=95)
            pixels.save(staging/crop_rel)
            values, _ = dino.extract(pixels)
            vector = feature_vector({'cls': values['cls'].tolist(), 'patch_mean': values['patch_mean'].tolist()})
            np.savez_compressed(staging/feature_rel, vector=vector)
            entries.append({'id': key, 'image_name': Path(row['file']).name, 'part': 'visible_upper_arm',
                            'image': image_rel, 'crop': crop_rel, 'features': feature_rel,
                            'source_sha256': row['source_sha256'], 'feature_schema': SCHEMA,
                            'model_revision': MODEL_REVISION, 'subject_hint': row.get('subject_hint', ''),
                            'split_hint': 'train', 'identity_confirmation_required': True,
                            'crop_box': row['normalized_box'], 'crop_method': 'visually_reviewed_exact_roi',
                            'resolution_policy': 'short>=64,long>=128; human review required',
                            'review_hashes': {'image': digest(staging/image_rel), 'crop': digest(staging/crop_rel)}})
        write_json(staging/'dataset.json', {'schema_version': 1, 'entries': entries, 'failures': [],
                    'input_images': len({r['source_sha256'] for r, _, _ in approved}), 'duplicates': 0,
                    'review_release': REVIEW_RELEASE})
        write_json(staging/'source-licenses.json', rows)
        write_json(staging/'pre_screening.json', {e['id']: {'status': 'needs_review',
            'reason': '원본과 상완 크롭·피부 노출을 확인했습니다. 작은 영역·자세·조명에 따라 윤곽이 불명확하면 제외하세요. 인물 ID는 사진별 임시값이며 같은 사람이면 같은 ID로 수정하세요.',
            'reviewer': 'assistant_visual_review', 'scope': 'source_and_crop',
            'human_confirmation_required': True} for e in entries})
        if output.exists():
            raise ValueError('출력 폴더가 작업 중 생성됐습니다.')
        staging.rename(output)
    return len(entries)


def validate_release(store):
    marked = 'review_release' in store.dataset
    if marked and store.dataset['review_release'] != REVIEW_RELEASE:
        raise ValueError('지원하지 않는 원본·크롭 검수 형식입니다.')
    for key, entry in store.entries.items():
        if not marked and 'review_hashes' not in entry:
            continue
        proofs = entry.get('review_hashes', {})
        for kind in ('image', 'crop'):
            if not proofs.get(kind) or digest(store.asset(key, kind)) != proofs[kind]:
                raise ValueError('원본·크롭 검수 해시가 없거나 검수 이후 파일이 변경됐습니다.')
