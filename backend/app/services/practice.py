from __future__ import annotations

import json
import sqlite3
from typing import Any

from .grading import stars_from_stats


def list_knowledge_points(conn: sqlite3.Connection, subject: str | None = None) -> list[dict[str, Any]]:
    if subject:
        rows = conn.execute(
            """
            SELECT kp.*, m.stars, m.correct_count, m.attempt_count
            FROM knowledge_points kp
            JOIN mastery m ON m.knowledge_point_id = kp.id
            WHERE kp.subject = ?
            ORDER BY kp.id
            """,
            (subject,),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT kp.*, m.stars, m.correct_count, m.attempt_count
            FROM knowledge_points kp
            JOIN mastery m ON m.knowledge_point_id = kp.id
            ORDER BY kp.subject, kp.id
            """
        ).fetchall()

    result = []
    for row in rows:
        item = dict(row)
        item["prerequisites"] = json.loads(item.pop("prerequisites_json"))
        result.append(item)
    return result


def question_to_public(row: sqlite3.Row | dict[str, Any], *, include_answer: bool = False) -> dict[str, Any]:
    data = dict(row)
    options = json.loads(data.pop("options_json"))
    public = {
        "id": data["id"],
        "subject": data["subject"],
        "knowledge_point_id": data["knowledge_point_id"],
        "type": data["type"],
        "stem": data["stem"],
        "options": options,
        "tts_text": data.get("tts_text"),
        "difficulty": data["difficulty"],
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
) -> list[dict[str, Any]]:
    params: list[Any] = []
    where = ["status = 'approved'"]
    if subject:
        where.append("subject = ?")
        params.append(subject)

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
        SELECT kp.*, m.stars, m.correct_count, m.attempt_count
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
    }
