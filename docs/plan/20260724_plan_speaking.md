# 实现计划 — 英语口语陪练模块

| 字段 | 内容 |
|------|------|
| 日期 | 2026-07-24 |
| 状态 | **Merged to main**（2026-07-24；S1～S3 留作 backlog） |
| 许可 | 已批准 |
| 关联讨论 | `docs/discussions/20260724_speaking_module.md` |
| 关联 PRD | `docs/prd/speaking_20260724.md` |
| 验收 | `docs/reviews/20260724_speaking_acceptance.md` |

## 阶段完成情况

| Phase | 状态 |
|-------|------|
| S1 内容与 API 骨架 | ✅ |
| S2 STT + 星级 + 点评 + 家长摘要 | ✅ |
| S3 SwiftUI 入口/录音/回放 | ✅ 源码 |
| S4 冒烟与验收文档 | ✅ |

## 主要新增路径

- `content/speaking_scripts.json`
- `backend/app/services/speaking.py` / `speech_score.py`
- `backend` speaking API routes
- `ios/.../SpeakingSessionView.swift` / `AudioRecorder.swift`
