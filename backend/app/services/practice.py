from __future__ import annotations

import json
import sqlite3
from typing import Any

from .grading import stars_from_stats


_SEMESTER_ORDER = """
CASE kp.semester
  WHEN 'upper' THEN 0
  WHEN 'lower' THEN 1
  ELSE 2
END
"""


def list_knowledge_points(conn: sqlite3.Connection, subject: str | None = None) -> list[dict[str, Any]]:
    if subject:
        rows = conn.execute(
            f"""
            SELECT kp.*, m.stars, m.correct_count, m.attempt_count,
                   EXISTS(
                     SELECT 1 FROM questions q
                     WHERE q.knowledge_point_id = kp.id AND q.status = 'approved'
                   ) AS has_questions
            FROM knowledge_points kp
            JOIN mastery m ON m.knowledge_point_id = kp.id
            WHERE kp.subject = ?
            ORDER BY {_SEMESTER_ORDER}, kp.sort_order, kp.id
            """,
            (subject,),
        ).fetchall()
    else:
        rows = conn.execute(
            f"""
            SELECT kp.*, m.stars, m.correct_count, m.attempt_count,
                   EXISTS(
                     SELECT 1 FROM questions q
                     WHERE q.knowledge_point_id = kp.id AND q.status = 'approved'
                   ) AS has_questions
            FROM knowledge_points kp
            JOIN mastery m ON m.knowledge_point_id = kp.id
            ORDER BY kp.subject, {_SEMESTER_ORDER}, kp.sort_order, kp.id
            """
        ).fetchall()

    result = []
    for row in rows:
        item = dict(row)
        item["prerequisites"] = json.loads(item.pop("prerequisites_json"))
        item["has_questions"] = bool(item.get("has_questions"))
        result.append(item)
    return result


def question_to_public(row: sqlite3.Row | dict[str, Any], *, include_answer: bool = False) -> dict[str, Any]:
    data = dict(row)
    options = json.loads(data.pop("options_json") or "[]")
    interaction_raw = data.pop("interaction_json", None)
    interaction = None
    if interaction_raw:
        interaction = json.loads(interaction_raw) if isinstance(interaction_raw, str) else interaction_raw
    diagram_raw = data.pop("diagram_json", None)
    diagram = None
    if diagram_raw:
        diagram = json.loads(diagram_raw) if isinstance(diagram_raw, str) else diagram_raw
    public = {
        "id": data["id"],
        "subject": data["subject"],
        "knowledge_point_id": data["knowledge_point_id"],
        "type": data["type"],
        "stem": data["stem"],
        "options": options,
        "tts_text": data.get("tts_text"),
        "difficulty": data["difficulty"],
        "interaction": interaction,
        "image_asset": data.get("image_asset"),
        "diagram": diagram,
    }
    if include_answer:
        public.update(
            {
                "answer": data["answer"],
                "explanation": data["explanation"],
                "seed": bool(data.get("seed", 0)),
                "status": data.get("status", "approved"),
            }
        )
    return public


def pick_questions(
    conn: sqlite3.Connection,
    *,
    mode: str,
    subject: str | None,
    count: int,
    knowledge_point_ids: list[str] | None = None,
) -> list[dict[str, Any]]:
    params: list[Any] = []
    where = ["q.status = 'approved'"]
    if subject:
        where.append("q.subject = ?")
        params.append(subject)

    kp_ids = [kid for kid in (knowledge_point_ids or []) if kid]
    if kp_ids:
        placeholders = ",".join("?" for _ in kp_ids)
        where.append(f"q.knowledge_point_id IN ({placeholders})")
        params.extend(kp_ids)

    if mode == "weak":
        sql = f"""
            SELECT q.* FROM questions q
            JOIN mastery m ON m.knowledge_point_id = q.knowledge_point_id
            WHERE {' AND '.join(where)}
            ORDER BY m.stars ASC, m.attempt_count ASC, RANDOM()
            LIMIT ?
        """
    elif mode == "habit":
        sql = f"""
            SELECT q.* FROM questions q
            WHERE {' AND '.join(where)}
            ORDER BY RANDOM()
            LIMIT ?
        """
    else:  # review
        sql = f"""
            SELECT q.* FROM questions q
            WHERE {' AND '.join(where)}
            ORDER BY q.difficulty ASC, RANDOM()
            LIMIT ?
        """
    params.append(count)
    rows = conn.execute(sql, params).fetchall()
    return [question_to_public(r) for r in rows]


def update_mastery(conn: sqlite3.Connection, knowledge_point_id: str, is_correct: bool, now: str) -> int:
    row = conn.execute(
        "SELECT correct_count, attempt_count FROM mastery WHERE knowledge_point_id = ?",
        (knowledge_point_id,),
    ).fetchone()
    if row is None:
        correct = 1 if is_correct else 0
        attempts = 1
        conn.execute(
            """
            INSERT INTO mastery (knowledge_point_id, correct_count, attempt_count, stars, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (knowledge_point_id, correct, attempts, stars_from_stats(correct, attempts), now),
        )
    else:
        correct = row["correct_count"] + (1 if is_correct else 0)
        attempts = row["attempt_count"] + 1
        conn.execute(
            """
            UPDATE mastery
            SET correct_count = ?, attempt_count = ?, stars = ?, updated_at = ?
            WHERE knowledge_point_id = ?
            """,
            (correct, attempts, stars_from_stats(correct, attempts), now, knowledge_point_id),
        )
    stars = stars_from_stats(correct, attempts)
    return stars


def parent_summary(conn: sqlite3.Connection) -> dict[str, Any]:
    totals = conn.execute(
        "SELECT COUNT(*) AS total, COALESCE(SUM(is_correct), 0) AS correct FROM attempts"
    ).fetchone()
    total = int(totals["total"])
    correct = int(totals["correct"])
    duration = conn.execute(
        "SELECT COALESCE(SUM(duration_seconds), 0) AS seconds FROM practice_sessions"
    ).fetchone()
    weak = conn.execute(
        """
        SELECT kp.*, m.stars, m.correct_count, m.attempt_count,
               EXISTS(
                 SELECT 1 FROM questions q
                 WHERE q.knowledge_point_id = kp.id AND q.status = 'approved'
               ) AS has_questions
        FROM knowledge_points kp
        JOIN mastery m ON m.knowledge_point_id = kp.id
        WHERE m.attempt_count > 0
        ORDER BY m.stars ASC, m.attempt_count DESC
        LIMIT 5
        """
    ).fetchall()
    weak_points = []
    for row in weak:
        item = dict(row)
        item["prerequisites"] = json.loads(item.pop("prerequisites_json"))
        item["has_questions"] = bool(item.get("has_questions"))
        weak_points.append(item)
    sessions = conn.execute(
        """
        SELECT id, mode, subject, started_at, ended_at, duration_seconds
        FROM practice_sessions
        ORDER BY started_at DESC
        LIMIT 10
        """
    ).fetchall()
    speaking = conn.execute(
        "SELECT COUNT(*) AS c, COALESCE(AVG(stars), 0) AS avg_stars FROM speaking_attempts"
    ).fetchone()
    speaking_duration = conn.execute(
        "SELECT COALESCE(SUM(duration_seconds), 0) AS seconds FROM speaking_sessions"
    ).fetchone()
    ext = conn.execute(
        """
        SELECT COALESCE(MAX(highest_cleared_level), 0) AS lvl
        FROM extension_progress
        WHERE activity_id = 'sudoku_symbols'
        """
    ).fetchone()
    return {
        "total_attempts": total,
        "correct_attempts": correct,
        "accuracy": round((correct / total), 3) if total else 0.0,
        "total_practice_seconds": int(duration["seconds"]),
        "weak_points": weak_points,
        "recent_sessions": [dict(s) for s in sessions],
        "speaking_attempts": int(speaking["c"]),
        "speaking_avg_stars": round(float(speaking["avg_stars"]), 2),
        "speaking_seconds": int(speaking_duration["seconds"]),
        "extension_sudoku_level": int(ext["lvl"] if ext else 0),
    }
