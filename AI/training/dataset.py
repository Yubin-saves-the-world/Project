"""Private dataset preparation and reviewed annotation storage."""
from __future__ import annotations

from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import threading

import numpy as np
from PIL import Image, ImageOps
import requests
from urllib.parse import urlparse

SCHEMA = 'dinov3-cls-patch-mean-v1'
LABELS = ('weak', 'medium', 'clear')
SPLITS = ('train', 'val', 'test')
DIMENSION = 768


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False))
    temporary.replace(path)


def local_api(url):
    parsed = urlparse(url)
    if parsed.scheme != 'http' or parsed.hostname not in {'127.0.0.1', 'localhost', '::1'} or parsed.username or parsed.password:
        raise ValueError('사진 처리 API는 로컬 주소만 허용합니다.')
    return url.rstrip('/')


def feature_vector(part):
    values = np.asarray(list(part['cls']) + list(part['patch_mean']), dtype=np.float64)
    if values.shape != (DIMENSION,) or not np.isfinite(values).all() or np.linalg.norm(values) < 1e-12:
        raise ValueError('올바른 768차원 DINOv3 특징이 필요합니다.')
    return values


def normalize_image(path):
    with Image.open(path) as source:
        if source.width * source.height > 25_000_000:
            raise ValueError('이미지 해상도가 너무 큽니다.')
        image = ImageOps.exif_transpose(source).convert('RGB')
        image.thumbnail((1024, 1024))
        buffer = io.BytesIO()
        image.save(buffer, format='JPEG', quality=95)
        buffer.seek(0)
        return Image.open(buffer).copy()


def prepare_dataset(images, directory, api='http://127.0.0.1:8001'):
    directory = Path(directory).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / 'dataset.json'
    if target.exists():
        raise ValueError('이미 준비한 데이터셋입니다. 기존 라벨을 보존하려면 서버를 --dataset만 지정해 실행하세요.')
    api = local_api(api)
    paths = sorted(p for p in Path(images).resolve().rglob('*') if p.is_file() and p.suffix.lower() in {'.jpg', '.jpeg', '.png'})
    entries, failures, seen = [], [], set()
    duplicates = 0
    for index, path in enumerate(paths, 1):
        print(f'[{index}/{len(paths)}] 사진 특징 준비', flush=True)
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        if sha in seen:
            duplicates += 1
            continue
        seen.add(sha)
        try:
            with path.open('rb') as stream:
                response = requests.post(api + '/v1/analyze', files={'front_images': (path.name, stream)}, timeout=120)
            if response.status_code != 200:
                detail = response.json().get('detail', {})
                failures.append({'image_name': path.name, 'code': detail.get('code', 'REQUEST_FAILED') if isinstance(detail, dict) else 'VALIDATION_FAILED'})
                continue
            result = response.json()
            write_json(directory / 'responses' / (sha + '.json'), {k: v for k, v in result.items() if k != 'debug_image_base64'})
            image = normalize_image(path)
            image_rel = 'images/' + sha + '.jpg'
            (directory / 'images').mkdir(exist_ok=True)
            image.save(directory / image_rel, quality=95)
            for part in result['dinov3']['parts']:
                if part['status'] != 'extracted':
                    failures.append({'image_name': path.name, 'part': part['part'], 'code': part.get('reason', 'UNAVAILABLE')})
                    continue
                vector = feature_vector(part)
                key = hashlib.sha256((sha + part['part'] + result['dinov3']['revision']).encode()).hexdigest()[:24]
                crop_rel, features_rel = f'crops/{key}.jpg', f'features/{key}.npz'
                for child in ('crops', 'features'):
                    (directory / child).mkdir(exist_ok=True)
                box = part['crop_box']
                if len(box) != 4 or not (0 <= box[0] < box[2] <= image.width and 0 <= box[1] < box[3] <= image.height):
                    raise ValueError('잘못된 상완 영역 좌표입니다.')
                image.crop(tuple(box)).save(directory / crop_rel, quality=95)
                np.savez_compressed(directory / features_rel, vector=vector)
                entries.append({'id': key, 'image_name': path.name, 'image': image_rel, 'crop': crop_rel,
                                'features': features_rel, 'source_sha256': sha, 'part': part['part'],
                                'feature_schema': SCHEMA, 'model_revision': result['dinov3']['revision']})
        except (OSError, ValueError, requests.RequestException) as exc:
            failures.append({'image_name': path.name, 'code': type(exc).__name__})
    if not entries:
        raise ValueError('라벨링할 특징을 추출하지 못했습니다. AI 서버 상태와 사진을 확인하세요.')
    data = {'schema_version': 1, 'entries': entries, 'input_images': len(paths), 'duplicates': duplicates, 'failures': failures}
    write_json(target, data)
    return data


class AnnotationStore:
    def __init__(self, directory):
        self.directory = Path(directory).resolve()
        self.dataset = json.loads((self.directory / 'dataset.json').read_text())
        self.entries = {entry['id']: entry for entry in self.dataset['entries']}
        self.path = self.directory / 'annotations.json'
        self.lock = threading.Lock()
        self.annotations = json.loads(self.path.read_text()) if self.path.exists() else {}

    def asset(self, key, kind):
        if key not in self.entries or kind not in {'image', 'crop', 'features'}:
            raise ValueError('존재하지 않는 데이터입니다.')
        path = (self.directory / self.entries[key][kind]).resolve()
        if not path.is_relative_to(self.directory) or not path.is_file():
            raise ValueError('잘못된 데이터 파일 경로입니다.')
        return path

    def save(self, key, subject_id, label, split, reason=''):
        import re
        if key not in self.entries or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', subject_id):
            raise ValueError('사진 ID와 인물 ID를 확인하세요. 인물 ID는 영문·숫자·밑줄·하이픈으로 입력하세요.')
        if label not in (*LABELS, 'exclude') or split not in SPLITS or (label == 'exclude' and not reason.strip()):
            raise ValueError('윤곽 라벨·데이터 구분을 선택하고 제외 시 이유를 입력하세요.')
        with self.lock:
            for other_key, annotation in self.annotations.items():
                if other_key == key or other_key not in self.entries:
                    continue
                same_image = self.entries[other_key]['source_sha256'] == self.entries[key]['source_sha256']
                if same_image and annotation['subject_id'] != subject_id:
                    raise ValueError('같은 사진의 좌우 상완에는 동일한 인물 ID를 입력하세요.')
                if annotation['subject_id'] == subject_id and annotation['split'] != split:
                    raise ValueError('동일 인물의 모든 사진은 같은 train/val/test 구분을 사용해야 합니다.')
            value = {'subject_id': subject_id, 'label': label, 'split': split, 'reason': reason.strip(), 'reviewed': True}
            updated = dict(self.annotations)
            updated[key] = value
            write_json(self.path, updated)
            self.annotations = updated
        return value

    def view(self):
        with self.lock:
            rows = []
            for key, entry in self.entries.items():
                annotation = self.annotations.get(key)
                hint = next((a for k, a in self.annotations.items() if k in self.entries and self.entries[k]['source_sha256'] == entry['source_sha256']), None)
                rows.append({'id': key, 'image_name': entry['image_name'], 'part': entry['part'],
                             'annotation': annotation, 'subject_hint': hint['subject_id'] if hint else entry.get('subject_hint', ''),
                             'split_hint': hint['split'] if hint else entry.get('split_hint', 'train')})
            return {'entries': rows, 'reviewed': len(self.annotations), 'total': len(rows),
                    'label_counts': dict(Counter(a['label'] for a in self.annotations.values())),
                    'failures': self.dataset.get('failures', [])}
