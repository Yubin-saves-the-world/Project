import argparse
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from training.independent import evaluate_independent


def main():
    p=argparse.ArgumentParser(description='학습에 사용하지 않은 사람 검수 자료의 윤곽 분류 평가')
    p.add_argument('--model',type=Path,required=True)
    p.add_argument('--training-dataset',type=Path,required=True)
    p.add_argument('--test-dataset',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--confirm-independent-identities',action='store_true')
    args=p.parse_args()
    paths=[x.resolve() for x in (args.model,args.training_dataset,args.test_dataset,args.output)]
    if any(not x.is_relative_to(ROOT/'.runtime') or any(p.startswith('quarantine_web_') for p in x.parts) for x in paths):
        raise ValueError('격리되지 않은 AI/.runtime 자료와 출력만 허용합니다.')
    result=evaluate_independent(*paths,identities_confirmed=args.confirm_independent_identities)
    print(json.dumps(result,ensure_ascii=False,indent=2))


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError) as exc:raise SystemExit(str(exc))
