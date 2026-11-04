"""Report actual imported Kaggle contents and prepare an unapproved inspection queue."""
import argparse
import json
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.dataset import write_json
from training.kaggle_sources import usage_summary, make_review_queue, inspect_tables


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=ROOT/'.runtime/kaggle_sources')
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_relative_to(ROOT/'.runtime') or any(p.startswith('quarantine_web_') for p in root.parts):
        raise ValueError('격리되지 않은 AI/.runtime의 Kaggle 원본만 검사합니다.')
    root.mkdir(parents=True, exist_ok=True)
    report = usage_summary(root)
    queue = make_review_queue(root)
    report['inspection_candidates'] = len(queue)
    for source in report['sources']:
        source['tables'] = inspect_tables(root/source['key'])
    write_json(root/'usage-plan.json', report)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
