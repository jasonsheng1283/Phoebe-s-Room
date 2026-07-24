from __future__ import annotations

import json
import logging
import sqlite3
import uuid
from typing import Any

import httpx

from ..config import get_settings
from ..db import utc_now
from .practice import update_mastery
from .speech_score import speech_similarity, stars_from_similarity, template_feedback

logger = logging.getLogger(__name__)


def list_prompts(conn: sqlite3.Connection, limit: int = 8) -> list[dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT id, type, knowledge_point_id, prompt_text, expected_text, tts_text, hint_zh, sort_order
        FROM speaking_prompts
        ORDER BY sort_order ASC, id ASC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()
    return [dict(r) for r in rows]


def prompt_public(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": row["id"],
        "type": row["type"],
        "knowledge_point_id": row["knowledge_point_id"],
        "prompt_text": row["prompt_text"],
        "tts_text": row.get("tts_text") or row["expected_text"],
        "hint_zh": row.get("hint_zh"),
        "expected_text": row["expected_text"],
    }


async def transcribe_audio(audio_bytes: bytes, filename: str = "audio.m4a") -> tuple[str, str]:
    """Return (transcript, source) where source is whisper|mock|empty."""
    settings = get_settings()
    if settings.stt_mock or not settings.llm_api_key:
        return "", "mock_pending"

    url = f"{settings.llm_base_url.rstrip('/')}/audio/transcriptions"
    mime = "audio/m4a"
    if filename.endswith(".wav"):
        mime = "audio/wav"
    elif filename.endswith(".mp3"):
        mime = "audio/mpeg"
    elif filename.endswith(".webm"):
        mime = "audio/webm"

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                url,
                headers={"Authorization": f"Bearer {settings.llm_api_key}"},
                files={"file": (filename, audio_bytes, mime)},
                data={"model": settings.stt_model, "language": "en"},
            )
            resp.raise_for_status()
            text = (resp.json().get("text") or "").strip()
            return text, "whisper"
    except Exception as exc:  # noqa: BLE001
        logger.warning("STT failed: %s", exc)
        return "", "stt_error"


async def maybe_llm_feedback(
    *,
    expected: str,
    transcript: str,
    stars: int,
    hint_zh: str | None,
    prompt_type: str,
) -> str:
    settings = get_settings()
    base = template_feedback(expected=expected, transcript=transcript, stars=stars, hint_zh=hint_zh)
    if not settings.llm_api_key:
        return base
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{settings.llm_base_url.rstrip('/')}/chat/completions",
                headers={"Authorization": f"Bearer {settings.llm_api_key}"},
                json={
                    "model": settings.llm_model,
                    "temperature": 0.5,
                    "messages": [
                        {
                            "role": "system",
                            "content": (
                                "你是温柔的爸爸兼朋友，辅导小学二年级英语口语。"
                                "用简短中文鼓励，可夹一点英文示范。不要恐吓，不要闲聊跑题。"
                                "只输出点评正文。"
                            ),
                        },
                        {
                            "role": "user",
                            "content": (
                                f"题型:{prompt_type}; 期望:{expected}; 转写:{transcript or '(未识别)'}; "
                                f"星级:{stars}/5; 提示:{hint_zh or ''}"
                            ),
                        },
                    ],
                },
            )
            resp.raise_for_status()
            content = resp.json()["choices"][0]["message"]["content"].strip()
            return content or base
    except Exception as exc:  # noqa: BLE001
        logger.warning("LLM feedback failed: %s", exc)
        return base


async def evaluate_attempt(
    conn: sqlite3.Connection,
    *,
    session_id: str,
    prompt_id: str,
    audio_bytes: bytes,
    filename: str,
    mock_transcript: str | None = None,
) -> dict[str, Any]:
    prompt = conn.execute("SELECT * FROM speaking_prompts WHERE id = ?", (prompt_id,)).fetchone()
    if prompt is None:
        raise KeyError("prompt_not_found")
    session = conn.execute("SELECT id FROM speaking_sessions WHERE id = ?", (session_id,)).fetchone()
    if session is None:
        raise KeyError("session_not_found")

    settings = get_settings()
    transcript = ""
    source = "none"
    if mock_transcript is not None and (settings.stt_mock or settings.debug or not settings.llm_api_key):
        transcript = mock_transcript.strip()
        source = "mock"
    elif audio_bytes:
        transcript, source = await transcribe_audio(audio_bytes, filename)
        if source == "mock_pending":
            # No key: cannot STT — require mock in tests; for clients return gentle low score path
            transcript = ""
            source = "unavailable"

    expected = prompt["expected_text"]
    score = speech_similarity(expected, transcript) if transcript else 0.0
    # If STT unavailable and no mock, give 2 stars encouragement path without claiming recognition
    if source == "unavailable":
        stars = 2
        feedback = (
            "我这边暂时听不清云端识别（可能还没配置语音服务）。"
            f"请先再听示范「{expected}」，大声跟读一遍。你很勇敢开口啦！"
        )
    else:
        stars = stars_from_similarity(score)
        feedback = await maybe_llm_feedback(
            expected=expected,
            transcript=transcript,
            stars=stars,
            hint_zh=prompt["hint_zh"],
            prompt_type=prompt["type"],
        )

    now = utc_now()
    # Treat 3+ stars as "correct-ish" for mastery
    is_good = stars >= 3 and source != "unavailable"
    mastery_stars = update_mastery(conn, prompt["knowledge_point_id"], is_good, now)

    conn.execute(
        """
        INSERT INTO speaking_attempts (
          session_id, prompt_id, transcript, stars, feedback, stt_source, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (session_id, prompt_id, transcript, stars, feedback, source, now),
    )

    return {
        "transcript": transcript,
        "stars": stars,
        "mastery_stars": mastery_stars,
        "feedback": feedback,
        "expected_text": expected,
        "tts_text": prompt["tts_text"] or expected,
        "knowledge_point_id": prompt["knowledge_point_id"],
        "stt_source": source,
        "similarity": round(score, 3),
    }


def speaking_stats(conn: sqlite3.Connection) -> dict[str, Any]:
    attempts = conn.execute("SELECT COUNT(*) AS c, COALESCE(AVG(stars), 0) AS avg_stars FROM speaking_attempts").fetchone()
    duration = conn.execute(
        "SELECT COALESCE(SUM(duration_seconds), 0) AS seconds FROM speaking_sessions"
    ).fetchone()
    return {
        "speaking_attempts": int(attempts["c"]),
        "speaking_avg_stars": round(float(attempts["avg_stars"]), 2),
        "speaking_seconds": int(duration["seconds"]),
    }
