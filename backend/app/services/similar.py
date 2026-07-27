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


def _seed_diagram(seed: dict[str, Any]) -> dict[str, Any] | None:
    raw = seed.get("diagram_json") if seed.get("diagram_json") is not None else seed.get("diagram")
    if isinstance(raw, str) and raw.strip():
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            return None
        return parsed if isinstance(parsed, dict) else None
    if isinstance(raw, dict):
        return json.loads(json.dumps(raw))
    return None


def _variant_diagram(diagram: dict[str, Any] | None, *, stem: str = "") -> dict[str, Any] | None:
    """Light param tweaks for similar questions; keep semantics aligned with stem."""
    if not diagram:
        return None
    d = json.loads(json.dumps(diagram))
    kind = d.get("kind")
    if kind == "angles":
        angles = d.get("angles_deg") or []
        if isinstance(angles, list) and angles:
            hi = int(d.get("highlight_index") or 0)
            d["highlight_index"] = (hi + 1) % len(angles)
    elif kind == "symmetry":
        shapes = ["heart", "butterfly", "rect"]
        cur = d.get("shape") or "heart"
        if cur in shapes:
            d["shape"] = shapes[(shapes.index(cur) + 1) % len(shapes)]
    elif kind == "observe":
        # Stem locked to a viewpoint → inherit only
        if any(tok in stem for tok in ("正面", "侧面", "上面", "顶面")):
            return d
        views = ["front", "side", "top"]
        cur = d.get("view") or "front"
        if cur in views:
            d["view"] = views[(views.index(cur) + 1) % len(views)]
    return d


def _align_stem_after_diagram_variant(
    stem: str,
    before: dict[str, Any] | None,
    after: dict[str, Any] | None,
) -> str:
    """When diagram params change, lightly sync stem so figure and text stay aligned."""
    if not before or not after or before == after:
        return stem
    text = stem.strip()
    kind = after.get("kind")
    if kind == "angles" and before.get("highlight_index") != after.get("highlight_index"):
        if "描得最明显" not in text and "高亮" not in text:
            base = re.sub(r"（变式）$", "", text).rstrip("。")
            return f"{base}。看看图里描得最明显的那个角。"
    if kind == "symmetry" and before.get("shape") != after.get("shape"):
        if "换了个图形" not in text and "另一个形状" not in text:
            base = re.sub(r"（变式）$", "", text).rstrip("。")
            return f"{base}。图换成另一个形状啦，对称轴还在吗？"
    if kind == "observe" and before.get("view") != after.get("view"):
        view_zh = {"front": "正面", "side": "侧面", "top": "上面"}
        new_zh = view_zh.get(str(after.get("view") or "front"), "正面")
        base = re.sub(r"（变式）$", "", text).rstrip("。")
        for old in ("正面", "侧面", "上面", "顶面"):
            if old in base:
                return base.replace(old, new_zh, 1) + "。"
        if "从图" not in base:
            return f"{base}。从图的{new_zh}看一看。"
    return stem


def _visual_bundle(seed: dict[str, Any], *, mutate_diagram: bool = True) -> tuple[dict[str, Any], str]:
    """Return (visual fields, stem possibly aligned to diagram variant)."""
    stem = str(seed.get("stem") or "")
    before = _seed_diagram(seed)
    after = _variant_diagram(before, stem=stem) if mutate_diagram else before
    aligned = _align_stem_after_diagram_variant(stem, before, after) if mutate_diagram else stem
    return (
        {
            "image_asset": seed.get("image_asset"),
            "diagram": after,
        },
        aligned,
    )


def _local_similar(seed: dict[str, Any]) -> dict[str, Any] | None:
    """Deterministic offline similar-question generator for math choice/true_false."""
    qtype = seed["type"]
    stem = seed["stem"]
    answer = str(seed["answer"])
    interaction = None
    raw_interaction = seed.get("interaction_json") or seed.get("interaction")
    if isinstance(raw_interaction, str) and raw_interaction.strip():
        interaction = json.loads(raw_interaction)
    elif isinstance(raw_interaction, dict):
        interaction = raw_interaction
    mutate = qtype in {"choice", "true_false"}
    visuals, aligned_stem = _visual_bundle(seed, mutate_diagram=mutate)

    if qtype == "true_false":
        out_stem = aligned_stem if aligned_stem.endswith("。") else aligned_stem + "。"
        return {
            "id": f"gen_{uuid.uuid4().hex[:10]}",
            "subject": seed["subject"],
            "knowledge_point_id": seed["knowledge_point_id"],
            "type": qtype,
            "stem": out_stem,
            "options": ["对", "错"],
            "answer": answer,
            "explanation": seed.get("explanation") or "再想一想，判断对不对。你能行的！",
            "tts_text": None,
            "difficulty": seed.get("difficulty", 1),
            "seed": False,
            "status": "approved",
            "interaction": None,
            **visuals,
        }

    if qtype == "choice":
        nums = [int(n) for n in re.findall(r"\d+", stem)]
        if len(nums) >= 2 and "+" in stem:
            a, b = nums[0], nums[1] + 1
            new_answer = str(a + b)
            new_stem = re.sub(rf"{nums[0]}\s*\+\s*{nums[1]}", f"{a} + {b}", stem, count=1)
            new_stem = re.sub(rf"{nums[0]}", str(a), new_stem, count=1) if new_stem == stem else new_stem
            base = int(new_answer)
            options = [str(base), str(base + 10), str(base - 10), str(base + 1)]
            seen: set[str] = set()
            uniq = []
            for o in options:
                if o not in seen and int(o) > 0:
                    seen.add(o)
                    uniq.append(o)
            return {
                "id": f"gen_{uuid.uuid4().hex[:10]}",
                "subject": seed["subject"],
                "knowledge_point_id": seed["knowledge_point_id"],
                "type": qtype,
                "stem": new_stem,
                "options": uniq[:4],
                "answer": new_answer,
                "explanation": f"这是一道练习变式。想一想：算完核对一遍。答案是 {new_answer}。你能行的！",
                "tts_text": None,
                "difficulty": seed.get("difficulty", 1),
                "seed": False,
                "status": "approved",
                "interaction": None,
                **visuals,
            }
        options = list(
            json.loads(seed["options_json"])
            if isinstance(seed.get("options_json"), str)
            else seed.get("options", [])
        )
        if len(options) >= 2:
            options = options[1:] + options[:1]
        choice_stem = aligned_stem if aligned_stem != stem else f"{stem}（变式）"
        return {
            "id": f"gen_{uuid.uuid4().hex[:10]}",
            "subject": seed["subject"],
            "knowledge_point_id": seed["knowledge_point_id"],
            "type": qtype,
            "stem": choice_stem,
            "options": options,
            "answer": answer,
            "explanation": seed.get("explanation") or "再练一遍，你能行！",
            "tts_text": None,
            "difficulty": seed.get("difficulty", 1),
            "seed": False,
            "status": "approved",
            "interaction": None,
            **visuals,
        }

    if qtype in {"drag_sort", "drag_place"}:
        # Keep interaction; light stem variant; no diagram on drag
        return {
            "id": f"gen_{uuid.uuid4().hex[:10]}",
            "subject": seed["subject"],
            "knowledge_point_id": seed["knowledge_point_id"],
            "type": qtype,
            "stem": stem + "（再试一次）",
            "options": [],
            "answer": answer,
            "explanation": seed.get("explanation") or "拖一拖，再检查一遍。",
            "tts_text": None,
            "difficulty": seed.get("difficulty", 1),
            "seed": False,
            "status": "approved",
            "interaction": interaction,
            "image_asset": seed.get("image_asset"),
            "diagram": None,
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
            "interaction": None,
            "image_asset": seed.get("image_asset"),
            "diagram": None,
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
    if generated["type"] == "true_false" and normalize_answer(generated["answer"]) not in {"对", "错"}:
        return False, "true_false_answer_invalid"
    if generated["type"] in {"drag_sort", "drag_place"} and not generated.get("interaction"):
        return False, "drag_needs_interaction"
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
            before = _seed_diagram(seed)
            after = _variant_diagram(before, stem=str(seed.get("stem") or ""))
            llm_stem = str(llm_data.get("stem") or seed.get("stem") or "")
            generated = {
                "id": f"gen_{uuid.uuid4().hex[:10]}",
                "subject": seed["subject"],
                "knowledge_point_id": seed["knowledge_point_id"],
                "type": seed["type"],
                "stem": _align_stem_after_diagram_variant(llm_stem, before, after),
                "options": llm_data.get("options") or [],
                "answer": str(llm_data.get("answer", "")).strip(),
                "explanation": llm_data.get("explanation") or "一起再看一遍解题思路吧。",
                "tts_text": llm_data.get("tts_text") or seed.get("tts_text"),
                "difficulty": seed["difficulty"],
                "seed": False,
                "status": "approved",
                "image_asset": seed.get("image_asset"),
                "diagram": after,
                "interaction": None,
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
          explanation, tts_text, difficulty, seed, status, interaction_json, image_asset,
          diagram_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 'approved', ?, ?, ?)
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
            json.dumps(generated["interaction"], ensure_ascii=False)
            if generated.get("interaction") is not None
            else None,
            generated.get("image_asset"),
            json.dumps(generated["diagram"], ensure_ascii=False)
            if generated.get("diagram") is not None
            else None,
        ),
    )
    return {"accepted": True, "reason": reason, "question": generated}
