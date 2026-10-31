"""Loopback-only labeling UI; serves only prepared private dataset assets."""
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel, Field

from .dataset import AnnotationStore

ROOT = Path(__file__).resolve().parents[1]


class Annotation(BaseModel):
    subject_id: str = Field(min_length=1, max_length=64)
    label: str
    split: str
    reason: str = Field(default='', max_length=200)


def create_app(directory, port=8002):
    store = AnnotationStore(directory)
    app = FastAPI(title='MOVID local contour labeling')
    allowed = {f'127.0.0.1:{port}', f'localhost:{port}'}

    @app.middleware('http')
    async def local_only(request: Request, call_next):
        if request.headers.get('host') not in allowed:
            return JSONResponse({'detail': '로컬 호스트만 허용합니다.'}, status_code=403)
        if request.method not in {'GET', 'HEAD', 'OPTIONS'}:
            origin = request.headers.get('origin')
            if origin and origin not in {'http://' + host for host in allowed}:
                return JSONResponse({'detail': '외부 사이트의 저장 요청을 차단했습니다.'}, status_code=403)
        return await call_next(request)

    @app.get('/', include_in_schema=False)
    def page():
        return FileResponse(ROOT / 'static/labeling.html')

    @app.get('/api/entries')
    def entries():
        return store.view()

    @app.get('/asset/{kind}/{key}')
    def asset(kind: str, key: str):
        if kind not in {'image', 'crop'}:
            raise HTTPException(404)
        try:
            path = store.asset(key, kind)
        except ValueError as exc:
            raise HTTPException(404, detail=str(exc)) from exc
        return FileResponse(path, headers={'Cache-Control': 'no-store'})

    @app.post('/api/annotations/{key}')
    def save(key: str, value: Annotation):
        try:
            annotation = store.save(key, value.subject_id, value.label, value.split, value.reason)
        except ValueError as exc:
            raise HTTPException(422, detail=str(exc)) from exc
        return {'saved': True, 'annotation': annotation}

    return app
