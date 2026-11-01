"""Export a labeling batch from explicit source-and-crop review evidence."""
import argparse
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.reviewed_crops import prepare

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        print('검수 라벨링 후보:', prepare(args.manifest, args.output))
    except (OSError, ValueError) as exc:
        raise SystemExit(str(exc))
