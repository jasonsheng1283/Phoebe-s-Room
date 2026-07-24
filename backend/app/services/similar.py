from __future__ import annotations

import json
import re
import sqlite3
import uuid
from typing import Any

import httpx

from ..config import get_settings
from ..db import utc_now
from .grading import normalize_answer
from .practice import question_to_public


def _local_similar(seed: dict[str, Any]) -> dict[str, Any] | None:
    """Deterministic offline similar-question generator for math fill/choice."""
    qtype = seed["type"]
    stem = seed["stem"]
    answer = str(seed["answer"])

    if qtype in {"fill", "choice", "word_problem"}:
        nums = [int(n) for n in re.findall(r"\d+", stem)]
        if len(nums) >= 2 and "+" in stem:
            a, b = nums[0], nums[1] + 1
            new_answer = str(a + b)
            new_stem = re.sub(rf"{nums[0]}\s*\+\s*{nums[1]}", f"{a} + {b}", stem, count=1)
            new_stem = re.sub(rf"{nums[0]}", str(a), new_stem, count=1) if new_stem == stem else new_stem
            if qtype == "word_problem":
                counter = {"n": 0}

                def replacer(match: re.Match[str]) -> str:
                    counter["n"] += 1
                    if counter["n"] == 1:
                        return str(a)
                    if counter["n"] == 2:
                        return str(b)
                    return match.group(0)

                new_stem = re.sub(r"\d+", replacer, stem, count=2)
            options = []
            if qtype == "choice":
                base = int(new_answer)
                options = [str(base), str(base + 10), str(base - 10), str(base + 1)]
                # keep unique order stable
                seen: set[str] = set()
                uniq = []
                for o in options:
                    if o not in seen and int(o) > 0:
                        seen.add(o)
                        uniq.append(o)
                options = uniq[:4]
            return {
                "id": f"gen_{uuid.uuid4().hex[:10]}",
                "subject": seed["subject"],
                "knowledge_point_id": seed["knowledge_point_id"],
                "type": qtype,
                "stem": new_stem,
                "options": options,
                "answer": new_answer,
                "explanation": f"这是一道练习变式。想一想：算完核对一遍。答案是 {new_answer}。你能行的！",
                "tts_text": None,
                "difficulty": seed.get("difficulty", 1),
                "seed": False,
                "status": "approved",
            }
    if qtype in {"phonics", "listening"}:
        # Swap distractor lightly while keeping answer
        options = list(json.loads(seed["options_json"]) if isinstance(seed.get("options_json"), str) else seed.get("options", []))
        if len(options) >= 2:
            options[0], options[-1] = options[-1], options[0]
        return {
            "id": f"gen_{uuid.uuid4().hex[:10]}",
            "subject": seed["subject"],
            "knowledge_point_id": seed["knowledge_point_id"],
            "type": qtype,
            "stem": seed["stem"] + "（变式）",
            "options": options,
            "answer": answer,
            "explanation": seed["explanation"],
            "tts_text": seed.get("tts_text"),
            "difficulty": seed.get("difficulty", 1),
            "seed": False,
            "status": "approved",
        }
    return None


def validate_generated(seed: dict[str, Any], generated: dict[str, Any]) -> tuple[bool, str]:
    if generated.get("knowledge_point_id") != seed["knowledge_point_id"]:
        return False, "knowledge_point_mismatch"
    if generated.get("type") != seed["type"]:
        return False, "type_mismatch"
    if not generated.get("stem") or not str(generated.get("answer", "")).strip():
        return False, "missing_stem_or_answer"
    if generated["type"] == "choice" and len(generated.get("options") or []) < 2:
        return False, "choice_needs_options"
    if generated["type"] == "choice" and normalize_answer(generated["answer"]) not in [
        normalize_answer(o) for o in generated["options"]
    ]:
        return False, "answer_not_in_options"
    # Basic age filter
    banned = ["杀", "赌", "暴力"]
    blob = f"{generated.get('stem','')}{generated.get('explanation','')}"
    if any(b in blob for b in banned):
        return False, "age_inappropriate"
    return True, "ok"


async def llm_generate(seed_public: dict[str, Any]) -> dict[str, Any] | None:
    settings = get_settings()
    if not settings.llm_api_key:
        return None
    prompt = {
        "role": "user",
        "content": (
            "你是小学二年级出题助手。根据种子题生成 1 道同知识点、同题型的相似题。"
            "只返回 JSON，字段: stem, options, answer, explanation, tts_text。"
            f"种子题: {json.dumps(seed_public, ensure_ascii=False)}"
        ),
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            f"{settings.llm_base_url.rstrip('/')}/chat/completions",
            headers={"Authorization": f"Bearer {settings.llm_api_key}"},
            json={
                "model": settings.llm_model,
                "messages": [
                    {"role": "system", "content": "输出合法 JSON。语气像爸爸和朋友，适合 7-8 岁。"},
                    prompt,
                ],
                "temperature": 0.4,
            },
        )
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"]["content"]
        # Extract JSON object
        match = re.search(r"\{.*\}", content, re.S)
        if not match:
            return None
        data = json.loads(match.group(0))
        return data


async def generate_similar(
    conn: sqlite3.Connection,
    seed_question_id: str,
    *,
    use_llm: bool = False,
) -> dict[str, Any]:
    row = conn.execute("SELECT * FROM questions WHERE id = ?", (seed_question_id,)).fetchone()
    if row is None:
        return {"accepted": False, "reason": "seed_not_found", "question": None}

    seed = dict(row)
    seed_public = question_to_public(row, include_answer=True)
    generated: dict[str, Any] | None = None

    if use_llm:
        llm_data = await llm_generate(seed_public)
        if llm_data:
            generated = {
                "id": f"gen_{uuid.uuid4().hex[:10]}",
                "subject": seed["subject"],
                "knowledge_point_id": seed["knowledge_point_id"],
                "type": seed["type"],
                "stem": llm_data.get("stem", ""),
                "options": llm_data.get("options") or [],
                "answer": str(llm_data.get("answer", "")).strip(),
                "explanation": llm_data.get("explanation") or "一起再看一遍解题思路吧。",
                "tts_text": llm_data.get("tts_text") or seed.get("tts_text"),
                "difficulty": seed["difficulty"],
                "seed": False,
                "status": "approved",
            }

    if generated is None:
        generated = _local_similar(seed)

    if generated is None:
        reason = "generation_failed"
        conn.execute(
            """
            INSERT INTO generation_logs (seed_question_id, payload_json, accepted, reason, created_at)
            VALUES (?, ?, 0, ?, ?)
            """,
            (seed_question_id, "{}", reason, utc_now()),
        )
        return {"accepted": False, "reason": reason, "question": None}

    ok, reason = validate_generated(seed, generated)
    conn.execute(
        """
        INSERT INTO generation_logs (seed_question_id, payload_json, accepted, reason, created_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        (seed_question_id, json.dumps(generated, ensure_ascii=False), 1 if ok else 0, reason, utc_now()),
    )
    if not ok:
        return {"accepted": False, "reason": reason, "question": None}

    conn.execute(
        """
        INSERT INTO questions (
          id, subject, knowledge_point_id, type, stem, options_json, answer,
          explanation, tts_text, difficulty, seed, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 'approved')
        """,
        (
            generated["id"],
            generated["subject"],
            generated["knowledge_point_id"],
            generated["type"],
            generated["stem"],
            json.dumps(generated.get("options") or [], ensure_ascii=False),
            generated["answer"],
            generated["explanation"],
            generated.get("tts_text"),
            int(generated.get("difficulty", 1)),
        ),
    )
    return {"accepted": True, "reason": reason, "question": generated}
