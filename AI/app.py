from __future__ import annotations

import shutil
import uuid
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, UploadFile

from analyzers.body_pipeline import analyze_body_images
from schemas.analysis_result import BodyAnalysisResponse


BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / "tmp_uploads"
RESULT_DIR = BASE_DIR / "results"
UPLOAD_DIR.mkdir(exist_ok=True)
RESULT_DIR.mkdir(exist_ok=True)

app = FastAPI(title="Project Vitality AI Server", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


def _save_upload(upload: UploadFile, request_dir: Path) -> str:
    suffix = Path(upload.filename or "image.jpg").suffix.lower() or ".jpg"
    target = request_dir / f"{uuid.uuid4().hex}{suffix}"
    with target.open("wb") as file:
        shutil.copyfileobj(upload.file, file)
    return str(target)


@app.post("/analyze/body", response_model=BodyAnalysisResponse)
def analyze_body(
    front_images: Annotated[list[UploadFile], File(description="One or more front full-body photos.")],
    text: Annotated[str | None, Form(description="Optional user text input.")] = None,
) -> BodyAnalysisResponse:
    request_id = uuid.uuid4().hex
    request_upload_dir = UPLOAD_DIR / request_id
    request_result_dir = RESULT_DIR / request_id
    request_upload_dir.mkdir(parents=True, exist_ok=True)
    request_result_dir.mkdir(parents=True, exist_ok=True)

    try:
        image_paths = [_save_upload(upload, request_upload_dir) for upload in front_images]
        return analyze_body_images(image_paths, str(request_result_dir), text_input=text)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
