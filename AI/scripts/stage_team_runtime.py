"""Copy original FE/BE into AI runtime without editing the team's source files."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
RUNTIME = ROOT / '.runtime/flutter_demo'
IGNORE = {'.git', '.gradle', '.gradle-local', 'build', '.dart_tool', '.idea', 'Pods', '.symlinks', 'ephemeral', '__pycache__', 'data'}


def stage():
    # Explicit directory rules: Flutter features/*/data is source and must be copied.
    manifest = {}
    for team in ('BE', 'FE'):
        source = REPO / team
        if not source.is_dir():
            raise ValueError('프로젝트 루트의 원본 FE와 BE 폴더가 필요합니다.')
        for path in source.rglob('*'):
            relative = path.relative_to(source)
            if not path.is_file() or path.is_symlink():
                continue
            if any(part in IGNORE - {'data'} for part in relative.parts) or (team == 'BE' and relative.parts[0] == 'data'):
                continue
            if path.name in {'.DS_Store', '.env', 'local.properties', '.flutter-plugins-dependencies'} or path.name.startswith('.env.'):
                continue
            if path.suffix in {'.pyc', '.log', '.iml'}:
                continue
            target = RUNTIME / team / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            content = path.read_bytes()
            if not target.is_file() or target.read_bytes() != content:
                shutil.copy2(path, target)
            manifest[f'{team}/{relative}'] = hashlib.sha256(content).hexdigest()
    RUNTIME.mkdir(parents=True, exist_ok=True)
    (RUNTIME / 'team-source-hashes.json').write_text(json.dumps(manifest, indent=2))
    return manifest


def verify_originals():
    manifest = json.loads((RUNTIME / 'team-source-hashes.json').read_text())
    for name, expected in manifest.items():
        if hashlib.sha256((REPO / name).read_bytes()).hexdigest() != expected:
            raise ValueError('원본 팀 소스가 변경됐습니다: ' + name)
    return len(manifest)


if __name__ == '__main__':
    print('Staged original files:', len(stage()))
