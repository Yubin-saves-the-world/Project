"""Experimental frozen DINOv3 features; no muscle classifier is trained."""
from __future__ import annotations

import math
import time

MODEL_ID = "facebook/dinov3-vits16-pretrain-lvd1689m"
MODEL_REVISION = "114c1379950215c8b35dfcd4e90a5c251dde0d32"


def upper_arm_box(landmarks, side, width, height, min_visibility=0.7):
    """Pixel crop around shoulder/elbow; visibility is not muscle visibility."""
    if side not in {"left", "right"}:
        raise ValueError("side must be left or right")
    points = [landmarks.get(f"{side}_{name}") for name in ("shoulder", "elbow")]
    if any(p is None for p in points):
        return None
    if any(not all(math.isfinite(float(p[k])) for k in ("x", "y", "visibility"))
           or p["visibility"] < min_visibility
           or not (0 <= p["x"] <= 1 and 0 <= p["y"] <= 1) for p in points):
        return None
    a, b = [(p["x"] * width, p["y"] * height) for p in points]
    length = math.dist(a, b)
    if length < 32:
        return None
    pad = length * 0.35
    box = (max(0, math.floor(min(a[0], b[0]) - pad)),
           max(0, math.floor(min(a[1], b[1]) - pad)),
           min(width, math.ceil(max(a[0], b[0]) + pad)),
           min(height, math.ceil(max(a[1], b[1]) + pad)))
    return box if min(box[2] - box[0], box[3] - box[1]) >= 32 else None


class DinoFeatureExtractor:
    def __init__(self, model=MODEL_ID, device="auto", revision=MODEL_REVISION, local_only=False):
        import torch
        from transformers import AutoImageProcessor, AutoModel

        self.torch = torch
        self.device = ("mps" if torch.backends.mps.is_available() else
                       "cuda" if torch.cuda.is_available() else "cpu") if device == "auto" else device
        self.processor = AutoImageProcessor.from_pretrained(
            model, revision=revision, local_files_only=local_only)
        self.model = AutoModel.from_pretrained(
            model, revision=revision, local_files_only=local_only,
            use_safetensors=True).eval().to(self.device)
        self.model.requires_grad_(False)
        self.model_id = model
        self.revision = getattr(self.model.config, "_commit_hash", None) or revision

    def _sync(self):
        if self.device.startswith("mps"):
            self.torch.mps.synchronize()
        elif self.device.startswith("cuda"):
            self.torch.cuda.synchronize()

    def extract(self, image):
        self._sync()
        start = time.perf_counter()
        inputs = self.processor(images=image, return_tensors="pt").to(self.device)
        with self.torch.inference_mode():
            hidden = self.model(**inputs).last_hidden_state
        # Exclude CLS and register tokens before pooling spatial patches.
        registers = self.model.config.num_register_tokens
        patches = hidden[:, 1 + registers:, :]
        self._sync()
        elapsed = time.perf_counter() - start
        cls = hidden[:, 0].float().cpu().numpy()[0]
        spatial = patches.float().cpu().numpy()[0]
        return {"cls": cls, "patches": spatial,
                "patch_mean": spatial.mean(axis=0)}, elapsed
