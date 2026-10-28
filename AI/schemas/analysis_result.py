from typing import Any

from pydantic import BaseModel, Field


class MetricJudgement(BaseModel):
    key: str
    label: str
    value: float | None = None
    severity: str
    message: str


class PriorityPart(BaseModel):
    targetIssue: str
    severity: str
    reason: str


class PostureResult(BaseModel):
    shoulderTiltDeg: float | None = None
    pelvisTiltDeg: float | None = None
    neckForwardDeg: float | None = None
    balanceScore: int | None = None
    metrics: dict[str, Any] = Field(default_factory=dict)


class BodyShapeResult(BaseModel):
    bodyType: str
    shoulderHipRatio: float | None = None
    torsoLegRatio: float | None = None
    waistChestRatio: float | None = None
    waistHipRatio: float | None = None
    abdomenChestRatio: float | None = None
    thighWaistRatio: float | None = None
    metrics: dict[str, Any] = Field(default_factory=dict)


class BodyAnalysisResponse(BaseModel):
    status: str = "done"
    measurementVersion: str = "mediapipe-seg-v1"
    posture: PostureResult
    bodyShape: BodyShapeResult
    judgements: list[MetricJudgement]
    priorityParts: list[PriorityPart]
    comparisonSummary: str
    comparisonDetail: str
    textSummary: str | None = None
    debugImages: list[str] = Field(default_factory=list)
    raw: dict[str, Any] = Field(default_factory=dict)
