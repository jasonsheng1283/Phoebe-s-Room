from __future__ import annotations

import uuid

from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile

from ..config import get_settings
from ..db import get_db, utc_now
from ..schemas import (
    EndSessionRequest,
    EndSpeakingRequest,
    ExtensionActivity,
    ExtensionProgressItem,
    GenerateSimilarRequest,
    GenerateSimilarResponse,
    HealthResponse,
    KnowledgePoint,
    ParentGateChallenge,
    ParentGateRequest,
    ParentSummary,
    SpeakingPrompt,
    SpeakingSubmitResponse,
    StartPracticeRequest,
    StartPracticeResponse,
    StartSpeakingRequest,
    StartSpeakingResponse,
    SubmitAnswerRequest,
    SubmitAnswerResponse,
    SudokuClearRequest,
    SudokuClearResponse,
    SudokuLevelResponse,
)
from ..services.grading import grade_answer
from ..services.practice import list_knowledge_points, parent_summary, pick_questions, question_to_public, update_mastery
from ..services.similar import generate_similar
from ..services.speaking import evaluate_attempt, list_prompts, prompt_public
from ..services.sudoku import (
    boards_equal,
    generate_sudoku_level,
    load_activities,
    public_level,
)

router = APIRouter()


def _assert_family(code: str) -> None:
    if code != get_settings().family_code:
        raise HTTPException(status_code=403, detail="invalid_family_code")


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", app=get_settings().app_name)


@router.get("/knowledge-points", response_model=list[KnowledgePoint])
def knowledge_points(subject: str | None = Query(default=None)) -> list[KnowledgePoint]:
    with get_db() as conn:
        rows = list_knowledge_points(conn, subject)
    return [KnowledgePoint(**r) for r in rows]


@router.post("/practice/start", response_model=StartPracticeResponse)
def start_practice(body: StartPracticeRequest) -> StartPracticeResponse:
    _assert_family(body.family_code)
    session_id = f"sess_{uuid.uuid4().hex[:12]}"
    with get_db() as conn:
        questions = pick_questions(
            conn,
            mode=body.mode,
            subject=body.subject,
            count=body.count,
            knowledge_point_ids=body.knowledge_point_ids,
        )
        if not questions:
            raise HTTPException(status_code=404, detail="no_questions")
        conn.execute(
            """
            INSERT INTO practice_sessions (id, mode, subject, started_at, duration_seconds)
            VALUES (?, ?, ?, ?, 0)
            """,
            (session_id, body.mode, body.subject, utc_now()),
        )
    return StartPracticeResponse(
        session_id=session_id,
        mode=body.mode,
        subject=body.subject,
        questions=questions,
    )


@router.post("/practice/submit", response_model=SubmitAnswerResponse)
def submit_answer(body: SubmitAnswerRequest) -> SubmitAnswerResponse:
    _assert_family(body.family_code)
    with get_db() as conn:
        session = conn.execute(
            "SELECT id FROM practice_sessions WHERE id = ?", (body.session_id,)
        ).fetchone()
        if session is None:
            raise HTTPException(status_code=404, detail="session_not_found")
        q = conn.execute("SELECT * FROM questions WHERE id = ?", (body.question_id,)).fetchone()
        if q is None:
            raise HTTPException(status_code=404, detail="question_not_found")
        is_correct = grade_answer(q["answer"], body.answer, q["type"])
        now = utc_now()
        conn.execute(
            """
            INSERT INTO attempts (session_id, question_id, user_answer, is_correct, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (body.session_id, body.question_id, body.answer, 1 if is_correct else 0, now),
        )
        stars = update_mastery(conn, q["knowledge_point_id"], is_correct, now)
        return SubmitAnswerResponse(
            is_correct=is_correct,
            correct_answer=q["answer"],
            explanation=q["explanation"],
            stars=stars,
            knowledge_point_id=q["knowledge_point_id"],
        )


@router.post("/practice/end")
def end_practice(body: EndSessionRequest) -> dict:
    _assert_family(body.family_code)
    with get_db() as conn:
        cur = conn.execute(
            """
            UPDATE practice_sessions
            SET ended_at = ?, duration_seconds = ?
            WHERE id = ?
            """,
            (utc_now(), body.duration_seconds, body.session_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="session_not_found")
    return {"ok": True}


@router.get("/parent/gate", response_model=ParentGateChallenge)
def parent_gate_challenge() -> ParentGateChallenge:
    # Fixed simple challenge for MVP determinism; UI can still feel like a gate
    return ParentGateChallenge(prompt="家长区：8 + 5 = ?", a=8, b=5)


@router.post("/parent/gate/verify")
def parent_gate_verify(body: ParentGateRequest) -> dict:
    _assert_family(body.family_code)
    if body.answer != 13:
        raise HTTPException(status_code=403, detail="gate_failed")
    return {"ok": True, "token": "parent-ok"}


@router.get("/parent/summary", response_model=ParentSummary)
def get_parent_summary(family_code: str = Query(default="phoebe-home")) -> ParentSummary:
    _assert_family(family_code)
    with get_db() as conn:
        data = parent_summary(conn)
    return ParentSummary(**data)


@router.post("/questions/generate-similar", response_model=GenerateSimilarResponse)
async def questions_generate_similar(body: GenerateSimilarRequest) -> GenerateSimilarResponse:
    _assert_family(body.family_code)
    with get_db() as conn:
        result = await generate_similar(conn, body.seed_question_id, use_llm=body.use_llm)
    question = result["question"]
    return GenerateSimilarResponse(
        accepted=result["accepted"],
        reason=result["reason"],
        question=question,
    )


@router.get("/questions/{question_id}")
def get_question(question_id: str, reveal: bool = False) -> dict:
    with get_db() as conn:
        row = conn.execute("SELECT * FROM questions WHERE id = ?", (question_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="question_not_found")
        return question_to_public(row, include_answer=reveal)


@router.post("/speaking/start", response_model=StartSpeakingResponse)
def start_speaking(body: StartSpeakingRequest) -> StartSpeakingResponse:
    _assert_family(body.family_code)
    session_id = f"spk_{uuid.uuid4().hex[:12]}"
    with get_db() as conn:
        prompts = list_prompts(conn, limit=body.count)
        if not prompts:
            raise HTTPException(status_code=404, detail="no_speaking_prompts")
        conn.execute(
            """
            INSERT INTO speaking_sessions (id, started_at, duration_seconds)
            VALUES (?, ?, 0)
            """,
            (session_id, utc_now()),
        )
    return StartSpeakingResponse(
        session_id=session_id,
        prompts=[SpeakingPrompt(**prompt_public(p)) for p in prompts],
    )


@router.post("/speaking/submit-audio", response_model=SpeakingSubmitResponse)
async def speaking_submit_audio(
    session_id: str = Form(...),
    prompt_id: str = Form(...),
    family_code: str = Form("phoebe-home"),
    mock_transcript: str | None = Form(default=None),
    file: UploadFile | None = File(default=None),
) -> SpeakingSubmitResponse:
    _assert_family(family_code)
    audio_bytes = await file.read() if file is not None else b""
    filename = file.filename if file and file.filename else "audio.m4a"
    with get_db() as conn:
        try:
            result = await evaluate_attempt(
                conn,
                session_id=session_id,
                prompt_id=prompt_id,
                audio_bytes=audio_bytes,
                filename=filename,
                mock_transcript=mock_transcript,
            )
        except KeyError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc
    return SpeakingSubmitResponse(**result)


@router.post("/speaking/end")
def end_speaking(body: EndSpeakingRequest) -> dict:
    _assert_family(body.family_code)
    with get_db() as conn:
        cur = conn.execute(
            """
            UPDATE speaking_sessions
            SET ended_at = ?, duration_seconds = ?
            WHERE id = ?
            """,
            (utc_now(), body.duration_seconds, body.session_id),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="session_not_found")
    return {"ok": True}


def _progress_level(conn, activity_id: str, grade: int) -> int:
    row = conn.execute(
        """
        SELECT highest_cleared_level FROM extension_progress
        WHERE activity_id = ? AND grade = ?
        """,
        (activity_id, grade),
    ).fetchone()
    return int(row["highest_cleared_level"]) if row else 0


@router.get("/extension/activities", response_model=list[ExtensionActivity])
def extension_activities(
    family_code: str = Query(default="phoebe-home"),
    grade: int = Query(default=2, ge=1, le=12),
) -> list[ExtensionActivity]:
    _assert_family(family_code)
    activities = load_activities()
    result: list[ExtensionActivity] = []
    with get_db() as conn:
        for act in activities:
            if not act.get("enabled", True):
                continue
            grades = act.get("grades") or []
            if grades and grade not in grades:
                continue
            cleared = _progress_level(conn, act["id"], grade)
            result.append(
                ExtensionActivity(
                    id=act["id"],
                    title=act["title"],
                    subtitle=act.get("subtitle") or "",
                    kind=act.get("kind") or "unknown",
                    grades=list(grades),
                    enabled=True,
                    highest_cleared_level=cleared,
                    next_level=cleared + 1,
                )
            )
    return result


@router.get("/extension/progress", response_model=list[ExtensionProgressItem])
def extension_progress(family_code: str = Query(default="phoebe-home")) -> list[ExtensionProgressItem]:
    _assert_family(family_code)
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT activity_id, grade, highest_cleared_level, updated_at
            FROM extension_progress
            ORDER BY activity_id, grade
            """
        ).fetchall()
    return [ExtensionProgressItem(**dict(r)) for r in rows]


@router.get("/extension/sudoku/level", response_model=SudokuLevelResponse)
def sudoku_level(
    family_code: str = Query(default="phoebe-home"),
    grade: int = Query(default=2, ge=1, le=12),
    level: int = Query(default=1, ge=1),
) -> SudokuLevelResponse:
    _assert_family(family_code)
    with get_db() as conn:
        cleared = _progress_level(conn, "sudoku_symbols", grade)
    # Allow current next level and any already cleared (replay)
    if level > cleared + 1:
        raise HTTPException(status_code=403, detail="level_locked")
    payload = public_level(generate_sudoku_level(family_code=family_code, grade=grade, level=level))
    return SudokuLevelResponse(**payload)


@router.post("/extension/sudoku/clear", response_model=SudokuClearResponse)
def sudoku_clear(body: SudokuClearRequest) -> SudokuClearResponse:
    _assert_family(body.family_code)
    full = generate_sudoku_level(family_code=body.family_code, grade=body.grade, level=body.level)
    if not boards_equal(body.board, full["solution"]):
        raise HTTPException(status_code=400, detail="incorrect_solution")
    with get_db() as conn:
        cleared = _progress_level(conn, "sudoku_symbols", body.grade)
        if body.level > cleared + 1:
            raise HTTPException(status_code=403, detail="level_locked")
        new_high = max(cleared, body.level)
        conn.execute(
            """
            INSERT INTO extension_progress (activity_id, grade, highest_cleared_level, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(activity_id, grade) DO UPDATE SET
              highest_cleared_level=excluded.highest_cleared_level,
              updated_at=excluded.updated_at
            """,
            ("sudoku_symbols", body.grade, new_high, utc_now()),
        )
    return SudokuClearResponse(ok=True, highest_cleared_level=new_high, next_level=new_high + 1)
