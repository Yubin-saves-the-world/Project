"""Check imports and gated model access before launching the server."""
import argparse
import importlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
MODEL_ID = 'facebook/dinov3-vits16-pretrain-lvd1689m'
REVISION = '114c1379950215c8b35dfcd4e90a5c251dde0d32'
FILES = ('config.json', 'preprocessor_config.json', 'model.safetensors')


def model_directory():
    model = os.environ.get('DINO_MODEL_PATH', MODEL_ID)
    path = Path(model).expanduser()
    if path.is_dir():
        if not all((path / name).is_file() for name in FILES):
            raise ValueError('로컬 모델 폴더에 config.json, preprocessor_config.json, model.safetensors가 필요합니다.')
        return path.resolve()
    if path.is_absolute() or model.startswith(('.', '~')):
        raise ValueError('DINO_MODEL_PATH의 로컬 폴더가 존재하지 않습니다.')
    from huggingface_hub import hf_hub_download
    from huggingface_hub.errors import GatedRepoError, HfHubHTTPError
    try:
        downloaded = [hf_hub_download(model, name, revision=REVISION if model == MODEL_ID else 'main') for name in FILES]
    except GatedRepoError as exc:
        raise ValueError('공식 모델 이용 승인과 로그인이 필요합니다. https://huggingface.co/' + MODEL_ID
                         + '\nAI 폴더에서 .venv/bin/hf auth login 후 다시 실행하세요. 토큰은 공유하지 마세요.') from exc
    except HfHubHTTPError as exc:
        raise ValueError('모델 다운로드 실패: 인터넷 연결과 Hugging Face 모델 접근 권한을 확인하세요.') from exc
    return Path(downloaded[0]).parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', action='store_true')
    args = parser.parse_args()
    if sys.version_info[:2] != (3, 12):
        raise ValueError('Python 3.12가 필요합니다.')
    for name in ('fastapi', 'uvicorn', 'multipart', 'cv2', 'numpy', 'PIL', 'mediapipe',
                 'torch', 'torchvision', 'transformers', 'joblib', 'sklearn'):
        importlib.import_module(name)
    import mediapipe as mp
    if not hasattr(mp, 'solutions'):
        raise ValueError('이 코드는 MediaPipe 0.10.21의 solutions API가 필요합니다. 고정된 requirements로 재설치하세요.')
    print('라이브러리 확인 완료.', flush=True)
    if args.model:
        directory = model_directory()
        runtime = ROOT / '.runtime'
        runtime.mkdir(exist_ok=True)
        (runtime / 'model.json').write_text(json.dumps({'path': str(directory)}))
        print('공식 모델 파일 확인 완료.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        raise SystemExit(str(exc))
