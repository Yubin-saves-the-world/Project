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
    parser.add_argument('--purpose', choices=['training','independent_test'], default='training')
    parser.add_argument('--reference-model', type=Path)
    parser.add_argument('--training-dataset', type=Path)
    args = parser.parse_args()
    try:
        if args.purpose=='independent_test' and (args.reference_model is None or args.training_dataset is None):
            raise ValueError('독립 시험 준비에는 --reference-model과 --training-dataset이 필요합니다.')
        if args.purpose!='independent_test' and (args.reference_model is not None or args.training_dataset is not None):
            raise ValueError('평가 모델 고정 옵션은 독립 시험 묶음에서만 사용합니다.')
        for path in (args.reference_model,args.training_dataset):
            if path is not None and (not path.resolve().is_relative_to(ROOT/'.runtime')
                                    or any(p.startswith('quarantine_web_') for p in path.resolve().parts)):
                raise ValueError('격리되지 않은 AI/.runtime 자료만 지정하세요.')
        print('검수 라벨링 후보:', prepare(args.manifest, args.output, purpose=args.purpose))
        if args.purpose=='independent_test':
            from training.independent import freeze_reference
            freeze_reference(args.output,args.reference_model,args.training_dataset)
            print('평가 모델 고정 완료. 학습에 통합하지 않습니다.')
    except (OSError, ValueError) as exc:
        raise SystemExit(str(exc))
