"""Compare fixed and inner-tuned regularization without replacing the live model."""
import argparse
import json
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.nested_cv import benchmark_nested


def main():
    parser = argparse.ArgumentParser(description='인물 분리 중첩 검증으로 윤곽 분류 학습 설정을 비교합니다.')
    parser.add_argument('--dataset', type=Path, default=ROOT/'.runtime/merged_reviewed_dataset')
    args = parser.parse_args()
    path = args.dataset.resolve()
    if not path.is_relative_to(ROOT/'.runtime'):
        raise ValueError('실험 결과는 AI/.runtime 데이터셋에만 저장합니다.')
    report = benchmark_nested(path)
    print(json.dumps({k: report[k] for k in ('samples', 'subjects', 'evaluation', 'final_selected_C',
                                           'deployed_model_changed')}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit(str(exc))
