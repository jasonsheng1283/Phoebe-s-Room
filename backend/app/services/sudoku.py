from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path
from typing import Any

from ..config import get_settings

SIZE = 4
BOX = 2

THEMES: list[dict[str, Any]] = [
    {
        "id": "shapes",
        "label": "形状",
        "symbols": [
            {"id": 0, "glyph": "●", "name": "圆"},
            {"id": 1, "glyph": "▲", "name": "三角"},
            {"id": 2, "glyph": "■", "name": "方块"},
            {"id": 3, "glyph": "★", "name": "星星"},
        ],
    },
    {
        "id": "fruit",
        "label": "水果",
        "symbols": [
            {"id": 0, "glyph": "🍎", "name": "苹果"},
            {"id": 1, "glyph": "🍌", "name": "香蕉"},
            {"id": 2, "glyph": "🍇", "name": "葡萄"},
            {"id": 3, "glyph": "🍊", "name": "橘子"},
        ],
    },
    {
        "id": "animals",
        "label": "小动物",
        "symbols": [
            {"id": 0, "glyph": "🐱", "name": "猫"},
            {"id": 1, "glyph": "🐶", "name": "狗"},
            {"id": 2, "glyph": "🐰", "name": "兔"},
            {"id": 3, "glyph": "🐻", "name": "熊"},
        ],
    },
    {
        "id": "vehicles",
        "label": "交通",
        "symbols": [
            {"id": 0, "glyph": "🚗", "name": "小车"},
            {"id": 1, "glyph": "🚌", "name": "巴士"},
            {"id": 2, "glyph": "🚲", "name": "单车"},
            {"id": 3, "glyph": "✈️", "name": "飞机"},
        ],
    },
]


def _rng(family_code: str, grade: int, level: int) -> random.Random:
    digest = hashlib.sha256(f"{family_code}|{grade}|{level}|sudoku4".encode()).hexdigest()
    return random.Random(int(digest[:16], 16))


def _clue_count_for_level(level: int) -> int:
    """Fewer clues => harder. Keep solvable unique puzzles."""
    if level <= 10:
        return max(8, 11 - (level - 1) // 3)
    if level <= 30:
        return max(6, 9 - (level - 11) // 5)
    if level <= 60:
        return max(5, 7 - (level - 31) // 8)
    return 4


def _theme_for_level(level: int) -> dict[str, Any]:
    return THEMES[(level - 1) % len(THEMES)]


def _pattern_row(r: int, c: int) -> int:
    return (BOX * (r % BOX) + r // BOX + c) % SIZE


def _shuffle(board_base: list[list[int]], rng: random.Random) -> list[list[int]]:
    rows = list(range(SIZE))
    # shuffle within bands
    for band in range(0, SIZE, BOX):
        block = rows[band : band + BOX]
        rng.shuffle(block)
        rows[band : band + BOX] = block
    cols = list(range(SIZE))
    for stack in range(0, SIZE, BOX):
        block = cols[stack : stack + BOX]
        rng.shuffle(block)
        cols[stack : stack + BOX] = block
    nums = list(range(SIZE))
    rng.shuffle(nums)
    return [[nums[board_base[r][c]] for c in cols] for r in rows]


def _full_board(rng: random.Random) -> list[list[int]]:
    base = [[_pattern_row(r, c) for c in range(SIZE)] for r in range(SIZE)]
    return _shuffle(base, rng)


def _find_empty(board: list[list[int | None]]) -> tuple[int, int] | None:
    for r in range(SIZE):
        for c in range(SIZE):
            if board[r][c] is None:
                return r, c
    return None


def _valid(board: list[list[int | None]], r: int, c: int, n: int) -> bool:
    if any(board[r][j] == n for j in range(SIZE)):
        return False
    if any(board[i][c] == n for i in range(SIZE)):
        return False
    br, bc = (r // BOX) * BOX, (c // BOX) * BOX
    for i in range(br, br + BOX):
        for j in range(bc, bc + BOX):
            if board[i][j] == n:
                return False
    return True


def _count_solutions(board: list[list[int | None]], limit: int = 2) -> int:
    empty = _find_empty(board)
    if empty is None:
        return 1
    r, c = empty
    count = 0
    for n in range(SIZE):
        if _valid(board, r, c, n):
            board[r][c] = n
            count += _count_solutions(board, limit)
            board[r][c] = None
            if count >= limit:
                return count
    return count


def _dig(board: list[list[int]], clues: int, rng: random.Random) -> list[list[int | None]]:
    puzzle: list[list[int | None]] = [[board[r][c] for c in range(SIZE)] for r in range(SIZE)]
    cells = [(r, c) for r in range(SIZE) for c in range(SIZE)]
    rng.shuffle(cells)
    target_remove = SIZE * SIZE - clues
    removed = 0
    for r, c in cells:
        if removed >= target_remove:
            break
        backup = puzzle[r][c]
        puzzle[r][c] = None
        probe = [[puzzle[i][j] for j in range(SIZE)] for i in range(SIZE)]
        if _count_solutions(probe, limit=2) != 1:
            puzzle[r][c] = backup
        else:
            removed += 1
    return puzzle


def generate_sudoku_level(*, family_code: str, grade: int, level: int) -> dict[str, Any]:
    if grade < 1:
        grade = 2
    if level < 1:
        level = 1
    rng = _rng(family_code, grade, level)
    solution = _full_board(rng)
    clues = _clue_count_for_level(level)
    puzzle = _dig(solution, clues, rng)
    theme = _theme_for_level(level)
    return {
        "activity_id": "sudoku_symbols",
        "grade": grade,
        "level": level,
        "size": SIZE,
        "box": BOX,
        "theme": {
            "id": theme["id"],
            "label": theme["label"],
            "symbols": theme["symbols"],
        },
        "givens": puzzle,
        "solution": solution,
        "clue_count": sum(1 for r in puzzle for v in r if v is not None),
    }


def public_level(payload: dict[str, Any]) -> dict[str, Any]:
    """Hide solution for client fetch."""
    return {k: v for k, v in payload.items() if k != "solution"}


def boards_equal(a: list[list[Any]], b: list[list[int]]) -> bool:
    if len(a) != SIZE or len(b) != SIZE:
        return False
    for r in range(SIZE):
        if len(a[r]) != SIZE or len(b[r]) != SIZE:
            return False
        for c in range(SIZE):
            try:
                if int(a[r][c]) != int(b[r][c]):
                    return False
            except (TypeError, ValueError):
                return False
    return True


def load_activities() -> list[dict[str, Any]]:
    path: Path = get_settings().content_path / "extension_activities.json"
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    return list(data.get("activities") or [])
