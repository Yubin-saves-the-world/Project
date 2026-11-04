import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.train import read_training_data, train


def main():
    parser = argparse.ArgumentParser(description='검수된 상완 윤곽 라벨로 동결 DINOv3 선형 분류기를 학습합니다.')
    parser.add_argument('--dataset', type=Path, default=ROOT / '.runtime/contour_dataset')
    parser.add_argument('--threshold', type=float, default=.6)
    parser.add_argument('--validate-only', action='store_true')
    args = parser.parse_args()
    directory = args.dataset.resolve()
    if not directory.is_relative_to(ROOT / '.runtime'):
        raise ValueError('학습 결과 저장 위치는 AI/.runtime 폴더 안이어야 합니다.')
    if args.validate_only:
        groups, classes, counts = read_training_data(directory)
        print('학습 사전 검사 통과:', classes, {split: len(rows) for split, rows in groups.items()}, counts)
        return
    _, report, _ = train(directory, args.threshold)
    print('실험용 윤곽 분류기 학습 완료. 근육량이나 근력 판정 모델이 아닙니다.')
    for split, result in report['evaluation'].items():
        print(split, '정확도', round(result['accuracy'], 4), 'Macro-F1', round(result['macro_f1'], 4),
              '사진/상완 영역 수', result['samples'], '인물 수', result['subjects'])
    print('모델:', directory / 'model.json')
    print('보고서:', directory / 'training-report.json')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit(str(exc))
