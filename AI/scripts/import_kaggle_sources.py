"""Download the selected public Kaggle archives without auto-labeling or serving images."""
import argparse
import json
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.kaggle_sources import acquire_all


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT/'.runtime/kaggle_sources')
    args = parser.parse_args()
    root = args.output.resolve()
    if not root.is_relative_to(ROOT/'.runtime') or any(p.startswith('quarantine_web_') for p in root.parts):
        raise ValueError('Kaggle 원본은 격리되지 않은 AI/.runtime 안에만 저장합니다.')
    root.mkdir(parents=True, exist_ok=True)
    records = acquire_all(root)
    print(json.dumps([{k: r.get(k) for k in ('ref','status','version','file_count','license')} for r in records], ensure_ascii=False, indent=2))
    if any(r['status'] != 'downloaded_unreviewed' for r in records):
        raise SystemExit('일부 자료를 받지 못했습니다. collection.json의 상태를 확인하세요.')


if __name__ == '__main__':
    main()
