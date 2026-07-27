#!/usr/bin/env python3
"""Smoke tests for Phoebe's Room API (no external LLM required)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient

from app.main import app


def main() -> None:
    with TestClient(app) as client:
        r = client.get("/api/v1/health")
        assert r.status_code == 200, r.text
        assert r.json()["status"] == "ok"

        r = client.get("/api/v1/knowledge-points")
        assert r.status_code == 200
        kps = r.json()
        assert len(kps) >= 8
        assert all("stars" in k for k in kps)

        r = client.post(
            "/api/v1/practice/start",
            json={"mode": "review", "subject": "math", "count": 3, "family_code": "phoebe-home"},
        )
        assert r.status_code == 200, r.text
        session = r.json()
        assert session["session_id"]
        assert len(session["questions"]) == 3
        q = session["questions"][0]

        r = client.post(
            "/api/v1/practice/start",
            json={
                "mode": "review",
                "subject": "math",
                "count": 2,
                "knowledge_point_ids": ["math.g2u.add_2digit_no_carry"],
                "family_code": "phoebe-home",
            },
        )
        assert r.status_code == 200, r.text
        filtered = r.json()["questions"]
        assert filtered
        assert all(item["knowledge_point_id"] == "math.g2u.add_2digit_no_carry" for item in filtered)

        r = client.post(
            "/api/v1/practice/start",
            json={
                "mode": "review",
                "subject": "math",
                "count": 2,
                "knowledge_point_ids": ["math.g2u.angle_right"],
                "family_code": "phoebe-home",
            },
        )
        assert r.status_code == 200, r.text
        drag_session = r.json()
        drag_q = next(q for q in drag_session["questions"] if q["type"] == "drag_place")
        assert drag_q.get("interaction")
        assert drag_q["interaction"].get("background_asset") == "scene_angles_three_v1"
        r = client.post(
            "/api/v1/practice/submit",
            json={
                "session_id": drag_session["session_id"],
                "question_id": drag_q["id"],
                "answer": '{"s2":"right"}',
                "family_code": "phoebe-home",
            },
        )
        assert r.status_code == 200, r.text
        assert r.json()["is_correct"] is True

        r = client.post(
            "/api/v1/practice/start",
            json={
                "mode": "review",
                "subject": "math",
                "count": 1,
                "knowledge_point_ids": ["math.g2u.angle_acute_obtuse"],
                "family_code": "phoebe-home",
            },
        )
        assert r.status_code == 200, r.text
        diagram_q = r.json()["questions"][0]
        assert diagram_q.get("diagram"), diagram_q
        assert diagram_q["diagram"].get("kind") == "angles"

        r = client.post(
            "/api/v1/questions/generate-similar",
            json={
                "seed_question_id": "q_math_angle_02",
                "family_code": "phoebe-home",
                "use_llm": False,
            },
        )
        assert r.status_code == 200, r.text
        gen_diagram = r.json()
        assert gen_diagram["accepted"] is True, gen_diagram
        assert gen_diagram["question"].get("diagram", {}).get("kind") == "angles"
        assert "描得最明显" in gen_diagram["question"]["stem"]

        detail = client.get(f"/api/v1/questions/{q['id']}", params={"reveal": True}).json()
        r = client.post(
            "/api/v1/practice/submit",
            json={
                "session_id": session["session_id"],
                "question_id": q["id"],
                "answer": detail["answer"],
                "family_code": "phoebe-home",
            },
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["is_correct"] is True
        assert body["stars"] >= 1
        assert body["explanation"]

        r = client.post(
            "/api/v1/practice/end",
            json={
                "session_id": session["session_id"],
                "duration_seconds": 120,
                "family_code": "phoebe-home",
            },
        )
        assert r.status_code == 200

        r = client.get("/api/v1/parent/gate")
        assert r.status_code == 200
        r = client.post(
            "/api/v1/parent/gate/verify",
            json={"answer": 13, "family_code": "phoebe-home"},
        )
        assert r.status_code == 200

        r = client.get("/api/v1/parent/summary", params={"family_code": "phoebe-home"})
        assert r.status_code == 200
        summary = r.json()
        assert summary["total_attempts"] >= 1

        r = client.post(
            "/api/v1/practice/start",
            json={"mode": "habit", "subject": "english", "count": 2, "family_code": "phoebe-home"},
        )
        assert r.status_code == 200, r.text
        assert len(r.json()["questions"]) == 2

        r = client.post(
            "/api/v1/questions/generate-similar",
            json={
                "seed_question_id": "q_math_add_01",
                "family_code": "phoebe-home",
                "use_llm": False,
            },
        )
        assert r.status_code == 200, r.text
        gen = r.json()
        assert gen["accepted"] is True, gen
        assert gen["question"]["id"].startswith("gen_")

        r = client.post(
            "/api/v1/practice/start",
            json={"mode": "weak", "count": 2, "family_code": "phoebe-home"},
        )
        assert r.status_code == 200

        # Speaking module
        r = client.post(
            "/api/v1/speaking/start",
            json={"family_code": "phoebe-home", "count": 4},
        )
        assert r.status_code == 200, r.text
        speaking = r.json()
        assert speaking["session_id"].startswith("spk_")
        assert len(speaking["prompts"]) >= 2
        echo = next(p for p in speaking["prompts"] if p["type"] == "echo")
        qa = next((p for p in speaking["prompts"] if p["type"] == "qa"), None)

        r = client.post(
            "/api/v1/speaking/submit-audio",
            data={
                "session_id": speaking["session_id"],
                "prompt_id": echo["id"],
                "family_code": "phoebe-home",
                "mock_transcript": echo["expected_text"],
            },
            files={"file": ("tiny.wav", b"RIFF....", "audio/wav")},
        )
        assert r.status_code == 200, r.text
        sp_body = r.json()
        assert sp_body["stars"] >= 4
        assert sp_body["feedback"]
        assert sp_body["stt_source"] == "mock"

        if qa:
            r = client.post(
                "/api/v1/speaking/submit-audio",
                data={
                    "session_id": speaking["session_id"],
                    "prompt_id": qa["id"],
                    "family_code": "phoebe-home",
                    "mock_transcript": "um " + qa["expected_text"],
                },
                files={"file": ("tiny.wav", b"RIFF....", "audio/wav")},
            )
            assert r.status_code == 200, r.text
            assert r.json()["stars"] >= 3

        r = client.post(
            "/api/v1/speaking/end",
            json={
                "session_id": speaking["session_id"],
                "duration_seconds": 180,
                "family_code": "phoebe-home",
            },
        )
        assert r.status_code == 200

        r = client.get("/api/v1/parent/summary", params={"family_code": "phoebe-home"})
        assert r.status_code == 200
        summary = r.json()
        assert summary["speaking_attempts"] >= 1
        assert summary["speaking_seconds"] >= 180
        assert "extension_sudoku_level" in summary

        r = client.get(
            "/api/v1/extension/activities",
            params={"family_code": "phoebe-home", "grade": 2},
        )
        assert r.status_code == 200, r.text
        acts = r.json()
        assert any(a["id"] == "sudoku_symbols" for a in acts)

        from app.services.sudoku import generate_sudoku_level

        full = generate_sudoku_level(family_code="phoebe-home", grade=2, level=1)
        r = client.get(
            "/api/v1/extension/sudoku/level",
            params={"family_code": "phoebe-home", "grade": 2, "level": 1},
        )
        assert r.status_code == 200, r.text
        assert "solution" not in r.json()
        assert r.json()["size"] == 4

        r = client.post(
            "/api/v1/extension/sudoku/clear",
            json={
                "family_code": "phoebe-home",
                "grade": 2,
                "level": 1,
                "board": full["solution"],
            },
        )
        assert r.status_code == 200, r.text
        assert r.json()["highest_cleared_level"] >= 1

    print("ALL SMOKE TESTS PASSED")


if __name__ == "__main__":
    main()
