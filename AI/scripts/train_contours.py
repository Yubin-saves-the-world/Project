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
    parser.add_argument('--evaluation', choices=['holdout','grouped-cv','fit-only'], default='holdout')
    parser.add_argument('--output', type=Path, help='fit-only 전용 새 모델 출력 폴더; AI/.runtime 내부')
    args = parser.parse_args()
    directory = args.dataset.resolve()
    if any(part.startswith('quarantine_web_') for part in directory.parts):
        raise ValueError('격리된 외부 자료는 학습에 사용할 수 없습니다.')
    if not directory.is_relative_to(ROOT / '.runtime'):
        raise ValueError('학습 결과 저장 위치는 AI/.runtime 폴더 안이어야 합니다.')
    if args.evaluation == 'fit-only':
        if args.validate_only or args.threshold != .6 or args.output is None:
            raise ValueError('fit-only는 --output 새 폴더와 고정 임계값 0.6이 필요합니다. 평가 명령이 아닙니다.')
        output = args.output.resolve()
        if not output.is_relative_to(ROOT / '.runtime') or any(p.startswith('quarantine_web_') for p in output.parts):
            raise ValueError('출력은 격리되지 않은 AI/.runtime 내부여야 합니다.')
        from training.fit_only import fit_only
        print(fit_only(directory, output))
        print('미검증 실험 모델입니다. 전체 입력으로 학습했으므로 별도 독립 평가 자료가 필요합니다.')
        return
    if args.output is not None:
        raise ValueError('--output은 fit-only에서만 사용합니다.')
    if args.evaluation == 'grouped-cv':
        if args.threshold != .6:
            raise ValueError('초기 교차검증 실험의 임계값은 0.6으로 고정합니다.')
        from training.grouped_cv import train_grouped_cv
        print(train_grouped_cv(directory, validate_only=args.validate_only))
        return
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
