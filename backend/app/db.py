from __future__ import annotations

import json
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

from .config import get_settings


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def connect() -> sqlite3.Connection:
    settings = get_settings()
    settings.db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(settings.db_path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


@contextmanager
def get_db() -> Iterator[sqlite3.Connection]:
    conn = connect()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, ddl: str) -> None:
    cols = {row[1] for row in conn.execute(f"PRAGMA table_info({table})").fetchall()}
    if column not in cols:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {ddl}")


def init_db() -> None:
    with get_db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS knowledge_points (
              id TEXT PRIMARY KEY,
              subject TEXT NOT NULL,
              name TEXT NOT NULL,
              prerequisites_json TEXT NOT NULL DEFAULT '[]',
              semester TEXT,
              sort_order INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS questions (
              id TEXT PRIMARY KEY,
              subject TEXT NOT NULL,
              knowledge_point_id TEXT NOT NULL,
              type TEXT NOT NULL,
              stem TEXT NOT NULL,
              options_json TEXT NOT NULL DEFAULT '[]',
              answer TEXT NOT NULL,
              explanation TEXT NOT NULL,
              tts_text TEXT,
              difficulty INTEGER NOT NULL DEFAULT 1,
              seed INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'approved',
              interaction_json TEXT,
              FOREIGN KEY (knowledge_point_id) REFERENCES knowledge_points(id)
            );

            CREATE TABLE IF NOT EXISTS mastery (
              knowledge_point_id TEXT PRIMARY KEY,
              correct_count INTEGER NOT NULL DEFAULT 0,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              stars INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (knowledge_point_id) REFERENCES knowledge_points(id)
            );

            CREATE TABLE IF NOT EXISTS practice_sessions (
              id TEXT PRIMARY KEY,
              mode TEXT NOT NULL,
              subject TEXT,
              started_at TEXT NOT NULL,
              ended_at TEXT,
              duration_seconds INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS attempts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id TEXT NOT NULL,
              question_id TEXT NOT NULL,
              user_answer TEXT NOT NULL,
              is_correct INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              FOREIGN KEY (session_id) REFERENCES practice_sessions(id),
              FOREIGN KEY (question_id) REFERENCES questions(id)
            );

            CREATE TABLE IF NOT EXISTS generation_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              seed_question_id TEXT,
              payload_json TEXT NOT NULL,
              accepted INTEGER NOT NULL,
              reason TEXT,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS speaking_prompts (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              knowledge_point_id TEXT NOT NULL,
              prompt_text TEXT NOT NULL,
              expected_text TEXT NOT NULL,
              tts_text TEXT,
              hint_zh TEXT,
              sort_order INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (knowledge_point_id) REFERENCES knowledge_points(id)
            );

            CREATE TABLE IF NOT EXISTS speaking_sessions (
              id TEXT PRIMARY KEY,
              started_at TEXT NOT NULL,
              ended_at TEXT,
              duration_seconds INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS speaking_attempts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id TEXT NOT NULL,
              prompt_id TEXT NOT NULL,
              transcript TEXT,
              stars INTEGER NOT NULL,
              feedback TEXT NOT NULL,
              stt_source TEXT,
              created_at TEXT NOT NULL,
              FOREIGN KEY (session_id) REFERENCES speaking_sessions(id),
              FOREIGN KEY (prompt_id) REFERENCES speaking_prompts(id)
            );

            CREATE TABLE IF NOT EXISTS extension_progress (
              activity_id TEXT NOT NULL,
              grade INTEGER NOT NULL,
              highest_cleared_level INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (activity_id, grade)
            );
            """
        )
        _ensure_column(conn, "knowledge_points", "semester", "semester TEXT")
        _ensure_column(conn, "knowledge_points", "sort_order", "sort_order INTEGER NOT NULL DEFAULT 0")
        _ensure_column(conn, "questions", "interaction_json", "interaction_json TEXT")
        _ensure_column(conn, "questions", "image_asset", "image_asset TEXT")
        _ensure_column(conn, "questions", "diagram_json", "diagram_json TEXT")
    seed_content()


def seed_content() -> None:
    settings = get_settings()
    kp_file = settings.content_path / "knowledge_points.json"
    q_file = settings.content_path / "seed_questions.json"
    speaking_file = settings.content_path / "speaking_scripts.json"
    if not kp_file.exists() or not q_file.exists():
        raise FileNotFoundError(f"Missing content under {settings.content_path}")

    kp_data = json.loads(kp_file.read_text(encoding="utf-8"))
    questions = json.loads(q_file.read_text(encoding="utf-8"))
    speaking_scripts = (
        json.loads(speaking_file.read_text(encoding="utf-8")) if speaking_file.exists() else []
    )

    with get_db() as conn:
        keep_ids_by_subject: dict[str, set[str]] = {}
        for subject in kp_data["subjects"]:
            subject_id = subject["id"]
            keep_ids_by_subject.setdefault(subject_id, set())
            for index, kp in enumerate(subject["knowledge_points"]):
                keep_ids_by_subject[subject_id].add(kp["id"])
                sort_order = int(kp.get("sort_order", index))
                conn.execute(
                    """
                    INSERT INTO knowledge_points (id, subject, name, prerequisites_json, semester, sort_order)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                      subject=excluded.subject,
                      name=excluded.name,
                      prerequisites_json=excluded.prerequisites_json,
                      semester=excluded.semester,
                      sort_order=excluded.sort_order
                    """,
                    (
                        kp["id"],
                        subject_id,
                        kp["name"],
                        json.dumps(kp.get("prerequisites", []), ensure_ascii=False),
                        kp.get("semester"),
                        sort_order,
                    ),
                )
                conn.execute(
                    """
                    INSERT INTO mastery (knowledge_point_id, correct_count, attempt_count, stars, updated_at)
                    VALUES (?, 0, 0, 0, ?)
                    ON CONFLICT(knowledge_point_id) DO NOTHING
                    """,
                    (kp["id"], utc_now()),
                )

        for q in questions:
            interaction = q.get("interaction")
            interaction_json = (
                json.dumps(interaction, ensure_ascii=False) if interaction is not None else None
            )
            image_asset = q.get("image_asset")
            diagram = q.get("diagram")
            diagram_json = json.dumps(diagram, ensure_ascii=False) if diagram is not None else None
            conn.execute(
                """
                INSERT INTO questions (
                  id, subject, knowledge_point_id, type, stem, options_json, answer,
                  explanation, tts_text, difficulty, seed, status, interaction_json, image_asset,
                  diagram_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'approved', ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  subject=excluded.subject,
                  knowledge_point_id=excluded.knowledge_point_id,
                  type=excluded.type,
                  stem=excluded.stem,
                  options_json=excluded.options_json,
                  answer=excluded.answer,
                  explanation=excluded.explanation,
                  tts_text=excluded.tts_text,
                  difficulty=excluded.difficulty,
                  seed=excluded.seed,
                  status=excluded.status,
                  interaction_json=excluded.interaction_json,
                  image_asset=excluded.image_asset,
                  diagram_json=excluded.diagram_json
                """,
                (
                    q["id"],
                    q["subject"],
                    q["knowledge_point_id"],
                    q["type"],
                    q["stem"],
                    json.dumps(q.get("options", []), ensure_ascii=False),
                    str(q["answer"]).strip(),
                    q["explanation"],
                    q.get("tts_text"),
                    int(q.get("difficulty", 1)),
                    1 if q.get("seed", True) else 0,
                    interaction_json,
                    image_asset,
                    diagram_json,
                ),
            )

        for sp in speaking_scripts:
            conn.execute(
                """
                INSERT INTO speaking_prompts (
                  id, type, knowledge_point_id, prompt_text, expected_text, tts_text, hint_zh, sort_order
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  type=excluded.type,
                  knowledge_point_id=excluded.knowledge_point_id,
                  prompt_text=excluded.prompt_text,
                  expected_text=excluded.expected_text,
                  tts_text=excluded.tts_text,
                  hint_zh=excluded.hint_zh,
                  sort_order=excluded.sort_order
                """,
                (
                    sp["id"],
                    sp["type"],
                    sp["knowledge_point_id"],
                    sp["prompt_text"],
                    sp["expected_text"],
                    sp.get("tts_text"),
                    sp.get("hint_zh"),
                    int(sp.get("sort_order", 0)),
                ),
            )

        # Drop obsolete knowledge points per subject (e.g. math ID redesign).
        for subject_id, keep_ids in keep_ids_by_subject.items():
            existing = conn.execute(
                "SELECT id FROM knowledge_points WHERE subject = ?",
                (subject_id,),
            ).fetchall()
            obsolete = [row["id"] for row in existing if row["id"] not in keep_ids]
            for kp_id in obsolete:
                qids = [
                    row["id"]
                    for row in conn.execute(
                        "SELECT id FROM questions WHERE knowledge_point_id = ?",
                        (kp_id,),
                    ).fetchall()
                ]
                for qid in qids:
                    conn.execute("DELETE FROM attempts WHERE question_id = ?", (qid,))
                conn.execute("DELETE FROM questions WHERE knowledge_point_id = ?", (kp_id,))
                conn.execute("DELETE FROM speaking_prompts WHERE knowledge_point_id = ?", (kp_id,))
                conn.execute("DELETE FROM mastery WHERE knowledge_point_id = ?", (kp_id,))
                conn.execute("DELETE FROM knowledge_points WHERE id = ?", (kp_id,))


def row_to_dict(row: sqlite3.Row | None) -> dict[str, Any] | None:
    if row is None:
        return None
    return dict(row)
