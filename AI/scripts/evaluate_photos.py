"""Real-photo execution and perturbation checks; no accuracy claim without labels."""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import numpy as np
from PIL import Image, ImageEnhance, ImageOps
import requests
from training.dataset import local_api, write_json


def request_result(api, data):
    started = time.perf_counter()
    response = requests.post(api + '/v1/analyze', files={'front_images': ('photo.jpg', data, 'image/jpeg')}, timeout=120)
    if response.status_code != 200:
        detail = response.json().get('detail', {})
        return {'status': 'failed', 'error_code': detail.get('code', 'REQUEST_FAILED') if isinstance(detail, dict) else 'VALIDATION_FAILED'}
    result = response.json()
    result.pop('debug_image_base64', None)
    result['request_seconds'] = time.perf_counter() - started
    return result


def changes(original, changed):
    if original.get('status') != 'done' or changed.get('status') != 'done':
        return {'status': changed.get('status'), 'error_code': changed.get('error_code')}
    deltas = {key: abs(float(value) - float(changed['measures'][key])) for key, value in original['measures'].items()
              if isinstance(value, (float, int)) and isinstance(changed['measures'].get(key), (float, int))}
    similarities = []
    for a in original['dinov3']['parts']:
        b = next((p for p in changed['dinov3']['parts'] if p['part'] == a['part']), None)
        if b and a['status'] == b['status'] == 'extracted':
            x, y = np.asarray(a['cls']), np.asarray(b['cls'])
            similarities.append(float(np.dot(x, y) / (np.linalg.norm(x) * np.linalg.norm(y))))
    return {'status': 'done', 'absolute_measure_deltas': deltas, 'cls_cosine_similarities': similarities}


def run(images, api, cache, output):
    api = local_api(api)
    files = sorted(p for p in Path(images).rglob('*') if p.is_file() and p.suffix.lower() in {'.jpg', '.jpeg', '.png'})
    if not files:
        raise ValueError('평가할 사진이 없습니다.')
    results = []
    for index, path in enumerate(files, 1):
        print(f'원본 검사 {index}/{len(files)}', flush=True)
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        cached = Path(cache) / 'responses' / (sha + '.json') if cache else None
        result = json.loads(cached.read_text()) if cached and cached.exists() else request_result(api, path.read_bytes())
        if cache and not (cached and cached.exists()):
            write_json(Path(cache) / 'responses' / (sha + '.json'), result)
        results.append((path, result))
    checks = []
    for index in sorted({0, len(results) // 2, len(results) - 1}):
        path, baseline = results[index]
        if baseline.get('status') != 'done':
            continue
        checks.append({'variant': 'repeat', 'image_name': path.name, **changes(baseline, request_result(api, path.read_bytes()))})
        with Image.open(path) as source:
            image = ImageOps.exif_transpose(source).convert('RGB')
            for name, variant, quality in [('brightness_0.7', ImageEnhance.Brightness(image).enhance(.7), 95),
                                            ('brightness_1.3', ImageEnhance.Brightness(image).enhance(1.3), 95),
                                            ('jpeg_quality_50', image, 50)]:
                data = io.BytesIO()
                variant.save(data, format='JPEG', quality=quality)
                checks.append({'variant': name, 'image_name': path.name, **changes(baseline, request_result(api, data.getvalue()))})
    done = [r for _, r in results if r.get('status') == 'done']
    regions = Counter(p['status'] for r in done for p in r['dinov3']['parts'])
    deltas = {}
    for item in checks:
        for key, value in item.get('absolute_measure_deltas', {}).items():
            deltas.setdefault(key, []).append(value)
    similarities = [value for row in checks for value in row.get('cls_cosine_similarities', [])]
    report = {'status': 'execution_checks_complete', 'original_images': len(files), 'photos_done': len(done),
              'photo_failures': dict(Counter(r.get('error_code', 'UNKNOWN') for _, r in results if r.get('status') != 'done')),
              'region_statuses': dict(regions), 'expected_regions_if_all_photos_usable': 2 * len(files),
              'ground_truth_available': False, 'classification_accuracy': None, 'measurement_accuracy': None,
              'perturbation_checks': len(checks), 'perturbation_failures': sum(c['status'] != 'done' for c in checks),
              'measure_delta_summary': {key: {'mean_absolute_delta': float(np.mean(values)), 'max_absolute_delta': float(max(values))} for key, values in deltas.items()},
              'cls_cosine_summary': {'mean': float(np.mean(similarities)), 'minimum': min(similarities)} if similarities else None,
              'checks': checks, 'note': '라벨 없는 사진의 실행 성공률·재현성 검사입니다. 분류 정확도·측정 정확도·정상 여부를 검증한 결과가 아닙니다.'}
    write_json(output, report)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--images', type=Path, required=True)
    parser.add_argument('--api', default='http://127.0.0.1:8001')
    parser.add_argument('--cache', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / '.runtime/evaluation/real-photos.json')
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(ROOT / '.runtime') or (args.cache and not args.cache.resolve().is_relative_to(ROOT / '.runtime')):
        raise SystemExit('결과·캐시 저장 위치는 AI/.runtime 폴더 안이어야 합니다.')
    result = run(args.images, args.api, args.cache, args.output)
    print(json.dumps({k: v for k, v in result.items() if k != 'checks'}, ensure_ascii=False, indent=2))
