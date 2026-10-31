"""Prepare reviewed upper-arm data and open the local labeling UI."""
import argparse
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from training.dataset import prepare_dataset
from training.label_server import create_app


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--images', type=Path, help='처음 준비할 원본 사진 폴더. 이미 준비한 데이터셋은 생략')
    parser.add_argument('--dataset', type=Path, default=ROOT / '.runtime/contour_dataset')
    parser.add_argument('--api', default='http://127.0.0.1:8001')
    parser.add_argument('--port', type=int, default=8002)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    dataset = args.dataset.resolve()
    if not dataset.is_relative_to(ROOT / '.runtime'):
        raise ValueError('데이터셋 저장 위치는 AI/.runtime 폴더 안이어야 합니다.')
    if not (dataset / 'dataset.json').exists():
        if not args.images or not args.images.is_dir():
            raise ValueError('처음에는 --images에 사진 폴더를 지정하세요.')
        prepare_dataset(args.images, dataset, args.api)
    if args.prepare_only:
        print('사진 특징 준비 완료. 라벨은 아직 입력되지 않았습니다.')
        return
    import uvicorn
    print(f'라벨링 화면: http://127.0.0.1:{args.port}\n실제 사진상 윤곽만 입력하세요. 옷으로 가려진 영역은 제외하세요.', flush=True)
    uvicorn.run(create_app(dataset, args.port), host='127.0.0.1', port=args.port)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit(str(exc))
