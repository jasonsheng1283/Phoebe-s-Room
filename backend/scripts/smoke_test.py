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

    print("ALL SMOKE TESTS PASSED")


if __name__ == "__main__":
    main()
