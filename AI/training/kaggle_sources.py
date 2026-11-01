"""Private Kaggle acquisition and inventory, separate from approved training data."""
from collections import Counter
import csv
import io
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import ssl
import stat
import urllib.parse
import urllib.request
import zipfile

from .dataset import write_json

SOURCES = {
    'body_measurements': ('unidpro/body-measurements-image-dataset', 'real_photo_measurements'),
    'body_size': ('tapakah68/body-measurements-dataset', 'real_photo_measurements'),
    'somaset': ('vicolab/somaset', 'synthetic_pose_shape'),
    'person_segmentation': ('tapakah68/supervisely-filtered-segmentation-person-dataset', 'segmentation'),
    'body_fat': ('fedesoriano/body-fat-prediction-dataset', 'numeric_body_fat'),
}
MAX_ARCHIVE = 5 * 1024**3
RESERVE_BYTES = 5 * 1024**3


def ssl_context():
    # Use OS trust when available; certificate verification is never disabled.
    try:
        import truststore
        return truststore.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    except ImportError:
        return ssl.create_default_context()


def open_url(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'MOVID-dataset-inventory/1.0'})
    return urllib.request.urlopen(request, timeout=45, context=ssl_context())


def safe_member(name):
    path = PurePosixPath(name.replace('\\', '/'))
    if path.is_absolute() or '..' in path.parts or any(':' in p for p in path.parts):
        raise ValueError('Archive member escapes the dataset directory')
    return path


def archive_inventory(path):
    counts = Counter()
    members = []
    expanded = 0
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            safe_member(item.filename)
            if stat.S_ISLNK(item.external_attr >> 16) or item.flag_bits & 1:
                raise ValueError('Linked or encrypted archive member is not allowed')
            if item.is_dir():
                continue
            expanded += item.file_size
            if len(members) >= 200_000 or expanded > 20 * 1024**3:
                raise ValueError('Archive inventory limit exceeded')
            suffix = PurePosixPath(item.filename).suffix.lower()
            counts[suffix or '(no extension)'] += 1
            members.append({'name': item.filename, 'bytes': item.file_size, 'crc32': item.CRC})
    return {'files': len(members), 'expanded_bytes': expanded, 'extensions': dict(counts), 'members': members}


def download_archive(url, target):
    target = Path(target)
    temporary = target.with_suffix('.part')
    size = 0
    digest = hashlib.sha256()
    try:
        with open_url(url) as response, temporary.open('wb') as stream:
            expected = response.headers.get('Content-Length')
            expected = int(expected) if expected and expected.isdigit() else None
            if expected and expected > MAX_ARCHIVE:
                raise ValueError('Download exceeds archive limit')
            next_progress = 32 * 1024**2
            while block := response.read(1024**2):
                size += len(block)
                if size > MAX_ARCHIVE or shutil.disk_usage(target.parent).free < RESERVE_BYTES + len(block):
                    raise ValueError('Download limit or free-space reserve reached')
                stream.write(block)
                digest.update(block)
                if size >= next_progress:
                    print(f'{target.parent.name}: {size // 1024**2} MiB downloaded', flush=True)
                    next_progress += 32 * 1024**2
            if expected is not None and size != expected:
                raise ValueError('Incomplete download')
        if not zipfile.is_zipfile(temporary):
            raise ValueError('Kaggle returned a non-ZIP response; authentication may be required')
        inventory = archive_inventory(temporary)
        with zipfile.ZipFile(temporary) as archive:
            if archive.testzip() is not None:
                raise ValueError('Archive CRC validation failed')
        temporary.replace(target)
        return {'bytes': size, 'sha256': digest.hexdigest()}, inventory
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def acquire_source(key, root):
    ref, purpose = SOURCES[key]
    directory = Path(root) / key
    directory.mkdir(parents=True, exist_ok=True)
    existing = directory/'source.json'
    if existing.exists():
        record = json.loads(existing.read_text())
        archive = directory/'download.zip'
        if record.get('status') == 'downloaded_unreviewed' and archive.is_file():
            with archive.open('rb') as stream:
                actual = hashlib.file_digest(stream, 'sha256').hexdigest()
            if actual == record['archive']['sha256']:
                print(key+': verified existing archive', flush=True)
                return record
            raise ValueError('Existing archive hash differs from the provenance record')
    record = {'ref': ref, 'url': 'https://www.kaggle.com/datasets/'+ref, 'purpose': purpose,
              'fetched_at': datetime.now(timezone.utc).isoformat(),
              'status': 'pending', 'approved_for_training': False, 'visually_reviewed': False,
              'contour_labels_available': False}
    try:
        with open_url('https://www.kaggle.com/api/v1/datasets/view/'+ref) as response:
            metadata = json.load(response)
        write_json(directory/'metadata.json', metadata)
        version = metadata.get('currentVersionNumber')
        if not isinstance(version, int) or isinstance(version, bool) or version < 1:
            raise ValueError('Dataset version is not available')
        record.update({'version': version, 'license': metadata.get('licenseName'), 'title': metadata.get('title')})
        url = 'https://www.kaggle.com/api/v1/datasets/download/'+ref+'?'+urllib.parse.urlencode({'datasetVersionNumber': version})
        record['status'] = 'downloading'
        write_json(existing, record)
        print(key+': downloading pinned version '+str(version), flush=True)
        details, inventory = download_archive(url, directory/'download.zip')
        write_json(directory/'inventory.json', inventory)
        record.update({'status': 'downloaded_unreviewed', 'archive': details,
                       'file_count': inventory['files'], 'extensions': inventory['extensions']})
    except Exception as exc:
        # Do not persist signed redirect URLs or credentials from network exceptions.
        record.update({'status': 'download_failed', 'error_type': type(exc).__name__})
        if isinstance(getattr(exc, 'code', None), int):
            record['http_status'] = exc.code
        print(key+': '+type(exc).__name__, flush=True)
    write_json(existing, record)
    return record


def acquire_all(root):
    results = []
    # Large SOMA archive last; small sources are ready even if it is interrupted.
    for key in ('body_fat', 'body_size', 'body_measurements', 'person_segmentation', 'somaset'):
        record = acquire_source(key, root)
        results.append(record)
        write_json(Path(root)/'collection.json', {'sources': results, 'approved_for_training': False})
    return results


def usage_summary(root):
    """Actual local contents, not advertised counts; no media display or label inference."""
    sources = []
    for key, (ref, purpose) in SOURCES.items():
        directory = Path(root)/key
        path = directory/'source.json'
        record = json.loads(path.read_text()) if path.exists() else {}
        inventory_path = directory/'inventory.json'
        inventory = json.loads(inventory_path.read_text()) if inventory_path.exists() else {'members': []}
        members = inventory['members']
        extensions = Counter(PurePosixPath(x['name']).suffix.lower() for x in members)
        images = sum(extensions[x] for x in ('.jpg', '.jpeg', '.png'))
        identities = set()
        if key == 'body_measurements':
            for item in members:
                parts = PurePosixPath(item['name']).parts
                if len(parts) > 1 and parts[0].isdigit():
                    identities.add(parts[0])
        elif key == 'somaset':
            for item in members:
                parts = PurePosixPath(item['name']).parts
                if len(parts) >= 3 and parts[-3].isdigit() and 1 <= int(parts[-3]) <= 50:
                    identities.add(parts[-3])
        image_suffixes = {'.jpg', '.jpeg', '.png'}
        if key == 'person_segmentation':
            role_counts = Counter(PurePosixPath(item['name']).parent.name for item in members
                                  if PurePosixPath(item['name']).suffix.lower() in image_suffixes)
            originals, masks, collages = (role_counts[name] for name in ('images', 'masks', 'collage'))
        elif key == 'body_measurements':
            originals = sum(len(PurePosixPath(item['name']).parts) > 1
                            and PurePosixPath(item['name']).parts[0].isdigit()
                            and PurePosixPath(item['name']).suffix.lower() in image_suffixes for item in members)
            masks = collages = 0
        else:
            originals, masks, collages = images, 0, 0
        part = directory/'download.part'
        status = 'downloading' if part.exists() else record.get('status', 'queued')
        usage = {'key': key, 'ref': ref, 'purpose': purpose, 'status': status,
                 'license': record.get('license'), 'version': record.get('version'),
                 'archive_bytes': record.get('archive', {}).get('bytes'),
                 'in_progress_bytes': part.stat().st_size if part.exists() else 0,
                 'files': len(members), 'image_files_including_masks': images,
                 'original_image_files': originals, 'mask_files': masks, 'collage_files': collages,
                 'extensions': dict(extensions),
                 'known_source_identities': len(identities) if identities else None,
                 'identity_kind': 'synthetic_avatar' if key == 'somaset' else 'human' if key == 'body_measurements' else 'not_established',
                 'training_approved': False, 'human_contour_labels': 0,
                 'next_step': 'numeric auxiliary data only' if key == 'body_fat' else
                              'inspect CSV references; no image files in this archive' if key == 'body_size' and not images else
                              'license/scope review, then original and crop review before human contour labeling'}
        sources.append(usage)
    return {'sources': sources, 'ready_for_contour_training': False,
            'note': 'Downloaded source images, masks and synthetic renders are not human-reviewed contour labels.'}


def make_review_queue(root):
    """Build a small, deterministic inspection list; never auto-approve candidates."""
    queue = []
    root = Path(root)
    for key in ('body_measurements', 'somaset', 'person_segmentation'):
        source = root/key
        if not (source/'inventory.json').exists() or not (source/'source.json').exists():
            continue
        record = json.loads((source/'source.json').read_text())
        inventory = json.loads((source/'inventory.json').read_text())
        selected = []
        for item in inventory['members']:
            name = item['name']
            path = PurePosixPath(name)
            if key == 'body_measurements':
                if path.name.lower() not in ('front_img.jpg', 'side_img.jpg'):
                    continue
                identity = 'kaggle_measurements_person'+path.parts[0]
            elif key == 'somaset':
                parts = path.parts
                if len(parts) < 3 or parts[-2] != '01' or path.name != '0001.jpg' or not parts[-3].isdigit():
                    continue
                identity = 'kaggle_somaset_avatar'+parts[-3]
            else:
                if path.suffix.lower() not in ('.jpg', '.jpeg', '.png') or 'images' not in path.parts:
                    continue
                identity = ''  # Different files must not be assumed to be different people.
            selected.append((name, identity))
        review_path = source/'original-review.json'
        reviewed = json.loads(review_path.read_text()) if review_path.exists() else []
        originals = {row['member'] for row in reviewed
                     if row.get('source_archive_sha256') == record['archive']['sha256']
                     and row.get('original_visually_reviewed') is True}
        for name, identity in sorted(selected)[:50]:
            queue.append({'source': key, 'archive_member': name, 'subject_hint': identity,
                          'source_archive_sha256': record['archive']['sha256'],
                          'review_status': 'original_checked_crop_pending' if name in originals else 'not_reviewed',
                          'license_scope_confirmed': False,
                          'original_visually_reviewed': name in originals, 'crop_visually_reviewed': False,
                          'human_contour_label': None})
    write_json(root/'review-queue.json', {'entries': queue, 'ready_for_training': False,
                'note': 'Inspection candidates only. Not served by the labeling UI and not added to training.'})
    return queue



def inspect_tables(directory):
    """Inspect CSV structure only; never follow referenced media links or run content."""
    directory = Path(directory)
    if not (directory/'download.zip').is_file():
        return []
    results = []
    with zipfile.ZipFile(directory/'download.zip') as archive:
        names = set(archive.namelist())
        for item in archive.infolist():
            if PurePosixPath(item.filename).suffix.lower() != '.csv':
                continue
            if item.file_size > 5 * 1024**2:
                results.append({'file': item.filename, 'status': 'size_limit'})
                continue
            text = archive.read(item).decode('utf-8-sig')
            try:
                dialect = csv.Sniffer().sniff(text[:10000], delimiters=',;\t')
            except csv.Error:
                dialect = csv.excel
            reader = csv.DictReader(io.StringIO(text), dialect=dialect)
            rows = missing = external = 0
            for row in reader:
                rows += 1
                if rows > 100_000:
                    raise ValueError('CSV row limit exceeded')
                for value in row.values():
                    if not isinstance(value, str):
                        continue
                    if value.startswith(('http://', 'https://')):
                        external += 1
                    elif '/' in value and PurePosixPath(value).suffix.lower() in {'.jpg', '.png', '.jpeg', '.json'}:
                        missing += value not in names
            results.append({'file': item.filename, 'status': 'inspected', 'rows': rows,
                            'columns': reader.fieldnames, 'external_link_cells': external,
                            'missing_relative_asset_references': missing})
    return results
