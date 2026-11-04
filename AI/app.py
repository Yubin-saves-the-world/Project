from __future__ import annotations
import logging
import os
import tempfile
import threading
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError
from integration import AnalysisEngine, AnalysisFailure

logger = logging.getLogger(__name__)
MAX_BYTES = 10 * 1024 * 1024
# Reject overload rather than queuing many 90-second backend jobs.
capacity = threading.BoundedSemaphore(1)

@asynccontextmanager
async def lifespan(app):
    model = os.environ.get('DINO_MODEL_PATH', 'facebook/dinov3-vits16-pretrain-lvd1689m')
    app.state.engine = AnalysisEngine(model, os.environ.get('AI_DEVICE','cpu'))
    yield

app = FastAPI(title='MOVID AI integration', version='1.0.0', lifespan=lifespan)

@app.get('/health')
def health():
    return {'status':'ok','dinov3_loaded':True,'device':app.state.engine.dino.device}

@app.post('/v1/analyze')
@app.post('/analyze/body')
def analyze(front_images: Annotated[list[UploadFile], File()]):
    if len(front_images) != 1:
        raise HTTPException(422, detail={'code':'VALIDATION_FAILED','message':'현재 통합 API는 정면 사진 1장을 받습니다.'})
    if not capacity.acquire(blocking=False):
        raise HTTPException(503, detail={'code':'AI_BUSY','message':'다른 사진을 분석 중이에요. 잠시 후 다시 시도해 주세요.'})
    try:
        data = front_images[0].file.read(MAX_BYTES+1)
        if len(data)>MAX_BYTES:
            raise HTTPException(413, detail={'code':'IMAGE_TOO_LARGE','message':'10MB 이하 사진을 사용해 주세요.'})
        with tempfile.TemporaryDirectory(prefix='movid-ai-') as directory:
            root=Path(directory)
            import io
            try:
                with Image.open(io.BytesIO(data)) as source:
                    if source.format not in ('JPEG','PNG'):
                        raise ValueError('Only JPEG/PNG supported')
                    if source.width * source.height > 25_000_000:
                        raise ValueError('Image resolution too large')
                    image=ImageOps.exif_transpose(source).convert('RGB')
                    image.thumbnail((1024,1024))
                    path=root/'input.jpg';image.save(path,quality=95)
            except (UnidentifiedImageError, ValueError, OSError, Image.DecompressionBombError) as exc:
                raise HTTPException(422,detail={'code':'INVALID_IMAGE','message':'올바른 JPG 또는 PNG 사진이 필요합니다.'}) from exc
            return app.state.engine.analyze(path, root)
    except AnalysisFailure as exc:
        raise HTTPException(422, detail={'code':exc.code,'message':exc.message}) from exc
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception('Analysis failed')
        raise HTTPException(500,detail={'code':'AI_FAILED','message':'분석 중 오류가 발생했습니다.'}) from exc
    finally:
        capacity.release()
