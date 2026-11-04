from __future__ import annotations

import io
import logging
import os
import tempfile
import threading
from contextlib import asynccontextmanager, contextmanager
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from PIL import Image, ImageOps, UnidentifiedImageError

from analyzers.body_pipeline import analyze_body_images
from integration import AnalysisEngine, AnalysisFailure
from schemas.analysis_result import BodyAnalysisResponse

logger = logging.getLogger(__name__)
MAX_BYTES = 10 * 1024 * 1024
capacity = threading.BoundedSemaphore(1)


@asynccontextmanager
async def lifespan(app):
    model = os.environ.get('DINO_MODEL_PATH', 'facebook/dinov3-vits16-pretrain-lvd1689m')
    app.state.engine = AnalysisEngine(model, os.environ.get('AI_DEVICE', 'cpu'))
    try:
        yield
    finally:
        if hasattr(app.state, 'flutter_bridge'):
            app.state.flutter_bridge.close()


app = FastAPI(title='MOVID AI server', version='1.0.0', lifespan=lifespan)


@app.get('/', include_in_schema=False)
def index():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'index.html')


@app.get('/health')
def health():
    return {'status': 'ok', 'dinov3_loaded': True, 'device': app.state.engine.dino.device,
            'contour_classifier_loaded': getattr(app.state.engine, 'contour', None) is not None}


def save_image(upload: UploadFile, root: Path, index: int = 0) -> Path:
    """Bound and normalize uploads without persisting originals or EXIF metadata."""
    data = upload.file.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise HTTPException(413, detail={'code': 'IMAGE_TOO_LARGE', 'message': '10MB 이하 사진을 사용해 주세요.'})
    try:
        with Image.open(io.BytesIO(data)) as source:
            if source.format not in ('JPEG', 'PNG') or source.width * source.height > 25_000_000:
                raise ValueError('Unsupported image format or resolution')
            image = ImageOps.exif_transpose(source).convert('RGB')
            image.thumbnail((1024, 1024))
            path = root / f'input-{index}.jpg'
            image.save(path, quality=95)
            return path
    except (UnidentifiedImageError, ValueError, OSError, Image.DecompressionBombError) as exc:
        raise HTTPException(422, detail={'code': 'INVALID_IMAGE', 'message': '올바른 JPG 또는 PNG 사진이 필요합니다.'}) from exc


@contextmanager
def analysis_slot():
    if not capacity.acquire(blocking=False):
        raise HTTPException(503, detail={'code': 'AI_BUSY', 'message': '다른 사진을 분석 중이에요. 잠시 후 다시 시도해 주세요.'})
    try:
        yield
    except AnalysisFailure as exc:
        raise HTTPException(422, detail={'code': exc.code, 'message': exc.message}) from exc
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception('Analysis failed')
        raise HTTPException(500, detail={'code': 'AI_FAILED', 'message': '분석 중 오류가 발생했습니다.'}) from exc
    finally:
        capacity.release()


@app.post('/v1/analyze')
def analyze(front_images: Annotated[list[UploadFile], File()]):
    if len(front_images) != 1:
        raise HTTPException(422, detail={'code': 'VALIDATION_FAILED', 'message': 'DINOv3 API는 정면 사진 1장을 받습니다.'})
    with analysis_slot(), tempfile.TemporaryDirectory(prefix='movid-ai-') as directory:
        root = Path(directory)
        return app.state.engine.analyze(save_image(front_images[0], root), root)


@app.post('/analyze/body', response_model=BodyAnalysisResponse)
def analyze_body(
    front_images: Annotated[list[UploadFile], File(description='Front full-body photos, up to 3.')],
    text: Annotated[str | None, Form(description='Optional user text input.')] = None,
) -> BodyAnalysisResponse:
    """Keep the team's existing camelCase response separate from the new DINOv3 API."""
    if not 1 <= len(front_images) <= 3:
        raise HTTPException(422, detail={'code': 'VALIDATION_FAILED', 'message': '기존 API는 사진 1~3장을 받습니다.'})
    with analysis_slot(), tempfile.TemporaryDirectory(prefix='movid-legacy-') as directory:
        root = Path(directory)
        paths = [str(save_image(upload, root, i)) for i, upload in enumerate(front_images)]
        return analyze_body_images(paths, str(root), text_input=text)


# Optional local adapter: keep the team FE/BE source unchanged.
if os.environ.get('AI_BACKEND_URL'):
    from bridge.api import install
    bridge_dir = Path(os.environ.get('AI_BRIDGE_DIR', str(Path(__file__).resolve().parent / '.runtime/flutter_demo/bridge'))).resolve()
    if not bridge_dir.is_relative_to(Path(__file__).resolve().parent / '.runtime'):
        raise ValueError('연동 데이터는 AI/.runtime 안에 저장해야 합니다.')
    install(app, bridge_dir, os.environ['AI_BACKEND_URL'], save_image)
