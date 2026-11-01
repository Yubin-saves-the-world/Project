"""Read-only readiness report; never edits labels or fits a model."""
import argparse
import json
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.readiness import readiness


def main():
    parser = argparse.ArgumentParser(description='검수 자료와 부족한 인물 수를 확인합니다.')
    parser.add_argument('--dataset', type=Path, default=ROOT / '.runtime/merged_reviewed_dataset')
    args = parser.parse_args()
    path = args.dataset.resolve()
    if not path.is_relative_to(ROOT / '.runtime') or any(p.startswith('quarantine_web_') for p in path.parts):
        raise ValueError('격리되지 않은 AI/.runtime 데이터셋만 검사할 수 있습니다.')
    print(json.dumps(readiness(path), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit(str(exc))
