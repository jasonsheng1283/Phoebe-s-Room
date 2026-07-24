from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


Mode = Literal["review", "weak", "habit"]
Subject = Literal["math", "english"]
QuestionType = Literal["choice", "fill", "word_problem", "phonics", "listening"]


class HealthResponse(BaseModel):
    status: str
    app: str


class KnowledgePoint(BaseModel):
    id: str
    subject: str
    name: str
    prerequisites: list[str] = Field(default_factory=list)
    stars: int = 0
    correct_count: int = 0
    attempt_count: int = 0


class QuestionPublic(BaseModel):
    id: str
    subject: str
    knowledge_point_id: str
    type: str
    stem: str
    options: list[str] = Field(default_factory=list)
    tts_text: str | None = None
    difficulty: int = 1


class QuestionWithAnswer(QuestionPublic):
    answer: str
    explanation: str
    seed: bool = False
    status: str = "approved"


class StartPracticeRequest(BaseModel):
    mode: Mode
    subject: Subject | None = None
    count: int = Field(default=5, ge=1, le=20)
    family_code: str = "phoebe-home"


class StartPracticeResponse(BaseModel):
    session_id: str
    mode: Mode
    subject: str | None
    questions: list[QuestionPublic]


class SubmitAnswerRequest(BaseModel):
    session_id: str
    question_id: str
    answer: str
    family_code: str = "phoebe-home"


class SubmitAnswerResponse(BaseModel):
    is_correct: bool
    correct_answer: str
    explanation: str
    stars: int
    knowledge_point_id: str


class EndSessionRequest(BaseModel):
    session_id: str
    duration_seconds: int = Field(default=0, ge=0)
    family_code: str = "phoebe-home"


class ParentGateRequest(BaseModel):
    answer: int
    family_code: str = "phoebe-home"


class ParentGateChallenge(BaseModel):
    prompt: str
    a: int
    b: int


class ParentSummary(BaseModel):
    total_attempts: int
    correct_attempts: int
    accuracy: float
    total_practice_seconds: int
    weak_points: list[KnowledgePoint]
    recent_sessions: list[dict[str, Any]]


class GenerateSimilarRequest(BaseModel):
    seed_question_id: str
    family_code: str = "phoebe-home"
    use_llm: bool = False


class GenerateSimilarResponse(BaseModel):
    accepted: bool
    reason: str
    question: QuestionWithAnswer | None = None
