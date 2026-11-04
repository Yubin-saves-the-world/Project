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
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from PIL import Image, ImageOps, UnidentifiedImageError

from analyzers.body_pipeline import analyze_body_images
from integration import AnalysisEngine, AnalysisFailure
from schemas.analysis_result import BodyAnalysisResponse
from pydantic import BaseModel, Field
from review_sessions import ReviewSessions
from routine_preview import RoutinePreviewRequest, preview_routine
from coach import LocalCoach, ChatRequest, BackendChatRequest, CoachFailure

review_sessions = ReviewSessions()
try:
    coach = LocalCoach()
except ValueError:
    coach = None

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
        review_sessions.clear()
        if hasattr(app.state, 'flutter_bridge'):
            app.state.flutter_bridge.close()
        app.state.engine.close()


app = FastAPI(title='MOVID AI server', version='1.0.0', lifespan=lifespan)


@app.exception_handler(RequestValidationError)
async def validation_error(request, exc):
    # Do not echo request values, paths, files or internal validation details.
    return JSONResponse(status_code=422, content={'detail': {
        'code': 'VALIDATION_FAILED', 'message': '입력 항목과 값을 확인해 주세요.'}})


@app.get('/', include_in_schema=False)
def index():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'home.html', headers={'Cache-Control':'no-store'})


@app.get('/analysis', include_in_schema=False)
def analysis_page():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'index.html')


@app.get('/coach', include_in_schema=False)
def coach_page():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'coach.html', headers={'Cache-Control':'no-store'})


@app.get('/coach/account', include_in_schema=False)
def account_coach_page():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'account-coach.html', headers={'Cache-Control':'no-store'})


@app.get('/assets/account-coach.mjs', include_in_schema=False)
def account_coach_script():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'account-coach.mjs',
                        media_type='text/javascript', headers={'Cache-Control':'no-store'})


@app.get('/assets/account-photo.mjs', include_in_schema=False)
def account_photo_script():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'account-photo.mjs',
                        media_type='text/javascript', headers={'Cache-Control':'no-store'})


@app.get('/v1/coach/health')
def coach_health():
    if coach is None:
        return {'status':'misconfigured','message':'코치 서버 설정을 확인해 주세요. 사진 측정은 별도로 사용할 수 있습니다.'}
    return coach.health()


@app.post('/v1/coach/chat')
def coach_chat(body: ChatRequest):
    if coach is None:
        raise HTTPException(503, detail={'code':'COACH_NOT_CONFIGURED','message':'코치 서버 설정을 확인해 주세요.'})
    try:
        return coach.chat(body)
    except CoachFailure as exc:
        raise HTTPException(exc.status, detail={'code':exc.code,'message':exc.message}) from exc


@app.post('/v1/chat')
def backend_coach_chat(body: BackendChatRequest):
    if coach is None:
        raise HTTPException(503, detail={'code':'COACH_NOT_CONFIGURED','message':'코치 서버 설정을 확인해 주세요.'})
    try:
        result = coach.chat(body)
    except CoachFailure as exc:
        raise HTTPException(exc.status, detail={'code':exc.code,'message':exc.message}) from exc
    return {'reply':result['message']['content'], 'model':result['model'],
            'seconds':result['processing_seconds'], 'response_source':result['response_source'],
            'truncated':result['truncated']}


@app.get('/routine', include_in_schema=False)
def routine_page():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'routine.html', headers={'Cache-Control':'no-store'})


@app.post('/v1/routines/preview')
def routine_preview(body: RoutinePreviewRequest):
    return preview_routine(body)


@app.get('/goal-compare', include_in_schema=False)
def goal_compare_page():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'goal-compare.html',
                        headers={'Cache-Control': 'no-store'})


@app.get('/assets/history.mjs', include_in_schema=False)
def history_script():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'history.mjs', media_type='text/javascript')


@app.get('/v1/data-readiness')
def data_readiness():
    configured = os.environ.get('AI_REVIEWED_DATASET')
    if not configured:
        return {'configured':False,'message':'검수 자료가 연결되지 않았습니다. 사진 분석은 사용할 수 있습니다.'}
    root = Path(__file__).resolve().parent / '.runtime'
    path = Path(configured).expanduser().resolve()
    if not path.is_relative_to(root) or any(p.startswith('quarantine_web_') for p in path.parts):
        raise HTTPException(503, detail={'message':'검수 자료 경로 설정을 확인하세요.'})
    try:
        from training.readiness import readiness
        report = readiness(path)
    except (OSError, ValueError, KeyError):
        raise HTTPException(503, detail={'message':'검수 자료를 읽지 못했습니다. 서버 설정을 확인하세요.'})
    return {'configured':True,'report':report}


@app.get('/contour-test', include_in_schema=False)
def contour_test():
    return FileResponse(Path(__file__).resolve().parent / 'static' / 'contour-test.html', headers={'Cache-Control': 'no-store'})


@app.get('/health')
def health():
    classifier = getattr(app.state.engine, 'contour', None)
    dino = getattr(app.state.engine, 'dino', None)
    guard = bool(getattr(app.state.engine, 'pose_guard', None))
    return {'status': 'ok' if dino is not None and guard else 'degraded',
            'dinov3_loaded': dino is not None, 'device': dino.device if dino is not None else None,
            'pose_guard_loaded': bool(getattr(app.state.engine, 'pose_guard', None)),
            'contour_classifier_loaded': classifier is not None,
            'contour_model': None if classifier is None else {
                'sha256': getattr(classifier, 'model_sha256', None),
                'classes': getattr(classifier, 'labels', []),
                'validation_status': getattr(classifier, 'validation_status', 'unspecified_experimental')},
            'capabilities': {'photo_measurement': True, 'balance_score': False, 'body_type': False,
                             'multiple_people_check': guard, 'frontal_check': False,
                             'contour_requires_review': True}}


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
def analyze(front_images: Annotated[list[UploadFile], File()],
            side_images: Annotated[list[UploadFile] | None, File()] = None,
            include_review_previews: Annotated[bool, Form()] = False):
    if len(front_images) != 1:
        raise HTTPException(422, detail={'code': 'VALIDATION_FAILED', 'message': 'DINOv3 API는 정면 사진 1장을 받습니다.'})
    if side_images is not None and len(side_images) != 1:
        raise HTTPException(422, detail={'code': 'VALIDATION_FAILED', 'message': '측면 사진은 최대 1장입니다.'})
    with analysis_slot(), tempfile.TemporaryDirectory(prefix='movid-ai-') as directory:
        root = Path(directory)
        kwargs = {}
        if side_images:
            kwargs['side_path'] = save_image(side_images[0], root, 1)
        if include_review_previews:
            kwargs['include_review_previews'] = True
        result = app.state.engine.analyze(save_image(front_images[0], root), root, **kwargs)
        if include_review_previews and getattr(app.state.engine, 'contour', None) is not None:
            for part in (result.get('dinov3') or {}).get('parts', []):
                if part.get('status') == 'extracted':
                    part['review_session'] = review_sessions.create(part['part'], part['cls'] + part['patch_mean'])
        return result


@app.post('/v1/compare')
def compare_photos(
    current_front: Annotated[UploadFile, File()],
    goal_front: Annotated[UploadFile, File()],
    current_side: Annotated[UploadFile | None, File()] = None,
    goal_side: Annotated[UploadFile | None, File()] = None,
    capture_conditions_confirmed: Annotated[bool, Form()] = False,
):
    """Compare geometry only; preserves the existing analyze/bridge contracts."""
    from goal_comparison import compare_measurements, measurement_view
    if not capture_conditions_confirmed:
        raise HTTPException(422, detail={'code': 'PHOTO_CONDITIONS_UNCONFIRMED',
                            'message': '두 사진의 방향·자세·카메라 높이와 거리가 비교 가능한지 확인하세요.'})
    with analysis_slot(), tempfile.TemporaryDirectory(prefix='movid-compare-') as directory:
        root = Path(directory)
        paths = {}
        # Validate every upload before running either model inference.
        for i, (key, upload) in enumerate((('current', current_front), ('goal', goal_front),
                                           ('current_side', current_side), ('goal_side', goal_side))):
            if upload is not None:
                paths[key] = save_image(upload, root, i)
        results = {}
        for key in ('current', 'goal'):
            output = root / key
            output.mkdir()
            try:
                results[key] = app.state.engine.analyze(paths[key], output,
                                                       side_path=paths.get(key+'_side'))
            except AnalysisFailure as exc:
                raise HTTPException(422, detail={'code': exc.code, 'message': exc.message,
                                                 'input': key}) from exc
        return {'status': 'done', 'comparison_version': 'photo-geometry-comparison-v1',
                'current': measurement_view(results['current']), 'goal': measurement_view(results['goal']),
                'goal_comparison': compare_measurements(results['current'], results['goal'])}


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
        result = analyze_body_images(paths, str(root), text_input=text)
        result.debugImages = []
        return result


@app.post('/v1/contour/classify')
def classify_reviewed_arm(image: Annotated[UploadFile, File()], skin_visible_confirmed: Annotated[bool, Form()] = False):
    if not skin_visible_confirmed:
        raise HTTPException(422, detail={'code': 'REVIEW_REQUIRED', 'message': '상완 피부가 보이는 적절한 크롭을 먼저 확인해 주세요.'})
    engine = app.state.engine
    if getattr(engine, 'contour', None) is None or getattr(engine, 'dino', None) is None:
        raise HTTPException(503, detail={'code': 'MODEL_NOT_CONFIGURED', 'message': '검수 라벨로 학습한 실험 모델을 설정하세요.'})
    with analysis_slot(), tempfile.TemporaryDirectory(prefix='movid-contour-') as directory:
        path = save_image(image, Path(directory))
        with engine.lock, Image.open(path) as photo:
            values, _ = engine.dino.extract(photo.convert('RGB'))
            prediction = engine.contour.predict(values['cls'].tolist() + values['patch_mean'].tolist())
        return {'status': 'done', 'scope': 'reviewed_upper_arm_crop', 'classification': prediction,
                'warnings': ['검수된 상완 크롭의 실험적 윤곽 분류입니다. 근육량·근력·체형 점수가 아닙니다.',
                             'candidate_label은 낮은 점수에서도 나오는 참고 후보이며 확정 판정이 아닙니다.']}


# Optional local adapter: keep the team FE/BE source unchanged.
if os.environ.get('AI_BACKEND_URL'):
    from bridge.api import install
    bridge_dir = Path(os.environ.get('AI_BRIDGE_DIR', str(Path(__file__).resolve().parent / '.runtime/flutter_demo/bridge'))).resolve()
    if not bridge_dir.is_relative_to(Path(__file__).resolve().parent / '.runtime'):
        raise ValueError('연동 데이터는 AI/.runtime 안에 저장해야 합니다.')
    install(app, bridge_dir, os.environ['AI_BACKEND_URL'], save_image, coach=coach)


class ReviewRequest(BaseModel):
    token: str = Field(min_length=40, max_length=64)
    skin_visible_confirmed: bool = False


@app.post('/v1/contour/review')
def review_extracted_arm(body: ReviewRequest):
    if not body.skin_visible_confirmed:
        raise HTTPException(422, detail={'code': 'REVIEW_REQUIRED', 'message': '상완 피부와 크롭 위치를 먼저 확인하세요.'})
    engine = app.state.engine
    if getattr(engine, 'contour', None) is None:
        raise HTTPException(503, detail={'code': 'MODEL_NOT_CONFIGURED', 'message': '실험 분류 모델이 설정되지 않았습니다.'})
    try:
        session = review_sessions.get(body.token)
    except KeyError:
        raise HTTPException(410, detail={'code': 'REVIEW_EXPIRED', 'message': '검수 시간이 지났습니다. 사진을 다시 분석하세요.'})
    with analysis_slot():
        return {'status': 'done', 'part': session['part'], 'scope': 'reviewed_upper_arm_crop',
                'classification': engine.contour.predict(session['features'])}
