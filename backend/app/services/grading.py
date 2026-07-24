from __future__ import annotations

import re


def normalize_answer(value: str) -> str:
    text = value.strip().lower()
    text = text.replace("，", ",").replace("。", ".")
    text = re.sub(r"\s+", "", text)
    # Chinese numerals / common suffixes for word problems like "37支"
    text = re.sub(r"(支|本|个|元|厘米|cm)$", "", text)
    return text


def grade_answer(expected: str, actual: str) -> bool:
    return normalize_answer(expected) == normalize_answer(actual)


def stars_from_stats(correct: int, attempts: int) -> int:
    if attempts <= 0:
        return 0
    rate = correct / attempts
    if attempts < 3:
        # early signal, cap at 3
        if rate >= 0.8:
            return 3
        if rate >= 0.5:
            return 2
        return 1
    if rate >= 0.9 and attempts >= 5:
        return 5
    if rate >= 0.8:
        return 4
    if rate >= 0.65:
        return 3
    if rate >= 0.45:
        return 2
    return 1
