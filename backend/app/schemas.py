from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


Mode = Literal["review", "weak", "habit"]
Subject = Literal["math", "english"]
QuestionType = Literal[
    "choice",
    "true_false",
    "drag_sort",
    "drag_place",
    "fill",
    "word_problem",
    "phonics",
    "listening",
]


class HealthResponse(BaseModel):
    status: str
    app: str


class KnowledgePoint(BaseModel):
    id: str
    subject: str
    name: str
    prerequisites: list[str] = Field(default_factory=list)
    semester: str | None = None
    sort_order: int = 0
    has_questions: bool = False
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
    interaction: dict[str, Any] | None = None
    image_asset: str | None = None
    diagram: dict[str, Any] | None = None


class QuestionWithAnswer(QuestionPublic):
    answer: str
    explanation: str
    seed: bool = False
    status: str = "approved"


class StartPracticeRequest(BaseModel):
    mode: Mode
    subject: Subject | None = None
    count: int = Field(default=5, ge=1, le=20)
    knowledge_point_ids: list[str] | None = None
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
    speaking_attempts: int = 0
    speaking_avg_stars: float = 0.0
    speaking_seconds: int = 0
    extension_sudoku_level: int = 0


class GenerateSimilarRequest(BaseModel):
    seed_question_id: str
    family_code: str = "phoebe-home"
    use_llm: bool = False


class GenerateSimilarResponse(BaseModel):
    accepted: bool
    reason: str
    question: QuestionWithAnswer | None = None


class SpeakingPrompt(BaseModel):
    id: str
    type: str
    knowledge_point_id: str
    prompt_text: str
    tts_text: str
    hint_zh: str | None = None
    expected_text: str


class StartSpeakingRequest(BaseModel):
    family_code: str = "phoebe-home"
    count: int = Field(default=6, ge=1, le=12)


class StartSpeakingResponse(BaseModel):
    session_id: str
    prompts: list[SpeakingPrompt]


class SpeakingSubmitResponse(BaseModel):
    transcript: str
    stars: int
    mastery_stars: int
    feedback: str
    expected_text: str
    tts_text: str
    knowledge_point_id: str
    stt_source: str
    similarity: float


class EndSpeakingRequest(BaseModel):
    session_id: str
    duration_seconds: int = Field(default=0, ge=0)
    family_code: str = "phoebe-home"


class ExtensionActivity(BaseModel):
    id: str
    title: str
    subtitle: str
    kind: str
    grades: list[int] = Field(default_factory=list)
    enabled: bool = True
    highest_cleared_level: int = 0
    next_level: int = 1


class SudokuSymbol(BaseModel):
    id: int
    glyph: str
    name: str


class SudokuTheme(BaseModel):
    id: str
    label: str
    symbols: list[SudokuSymbol]


class SudokuLevelResponse(BaseModel):
    activity_id: str
    grade: int
    level: int
    size: int
    box: int
    theme: SudokuTheme
    givens: list[list[int | None]]
    clue_count: int


class SudokuClearRequest(BaseModel):
    family_code: str = "phoebe-home"
    grade: int = 2
    level: int = Field(ge=1)
    board: list[list[int]]


class SudokuClearResponse(BaseModel):
    ok: bool
    highest_cleared_level: int
    next_level: int


class ExtensionProgressItem(BaseModel):
    activity_id: str
    grade: int
    highest_cleared_level: int
    updated_at: str

