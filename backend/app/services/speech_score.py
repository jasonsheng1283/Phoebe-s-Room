from __future__ import annotations

import re
from difflib import SequenceMatcher


def normalize_speech_text(value: str) -> str:
    text = value.strip().lower()
    text = text.replace("，", " ").replace(",", " ").replace("。", " ").replace(".", " ")
    text = re.sub(r"[^a-z0-9\s']", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def speech_similarity(expected: str, transcript: str) -> float:
    a = normalize_speech_text(expected)
    b = normalize_speech_text(transcript)
    if not a:
        return 0.0
    if not b:
        return 0.0
    if a == b:
        return 1.0
    # Allow expected as a token inside longer transcript ("it is a cat")
    if a in b.split() or a in b:
        return max(0.85, SequenceMatcher(None, a, b).ratio())
    return SequenceMatcher(None, a, b).ratio()


def stars_from_similarity(score: float) -> int:
    # Generous for grade-2 speakers
    if score >= 0.92:
        return 5
    if score >= 0.78:
        return 4
    if score >= 0.6:
        return 3
    if score >= 0.4:
        return 2
    return 1


def template_feedback(*, expected: str, transcript: str, stars: int, hint_zh: str | None) -> str:
    hint = hint_zh or ""
    if stars >= 4:
        return f"说得很棒！我听到的是「{transcript or expected}」。再听一遍示范，巩固一下～ {hint}".strip()
    if stars >= 3:
        return f"不错哦！目标是「{expected}」，我听到有点像「{transcript or '…'}」。再跟我读一次会更清楚。{hint}".strip()
    return (
        f"没关系，我们慢慢来。目标是「{expected}」。先听示范，再轻轻说一遍。"
        f"{(' ' + hint) if hint else ''}"
    ).strip()
