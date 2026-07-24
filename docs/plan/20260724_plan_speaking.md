# 实现计划 — 英语口语陪练模块

| 字段 | 内容 |
|------|------|
| 日期 | 2026-07-24 |
| 状态 | **Draft — 等待明确开发许可** |
| 关联讨论 | `docs/discussions/20260724_speaking_module.md` |
| 关联 PRD | `docs/prd/speaking_20260724.md` |
| 性质 | 新功能（影响客户端、后端、内容、隐私） |

---

## 1. 目标

为 iPad App 增加**独立入口**的英语口语陪练：跟读 + 少量问答；录音回放；云端 STT；鼓励+示范+星级；联动英语知识点与家长摘要。

## 2. 已确认结论

- 跟读 + 少量问答；独立入口；鼓励+示范+星级；云端语音可出域；MVP 要完整闭环（含回放与 AI 点评）

## 3. 改动范围（许可后）

| 模块 | 改动 |
|------|------|
| `ios/PhoebeRoom/` | 首页口语入口；录音/回放；口语会话页；麦克风权限 |
| `backend/` | 口语会话 API、音频上传、STT 代理、点评/星级、家长摘要扩展 |
| `content/` | 口语跟读/问答种子剧本 |
| `docs/legal/privacy_draft.md` | 麦克风与语音出域 |
| `docs/features.md` 等 | 状态同步 |

### 不改动

- 数学习题流、自由闲聊、第三方专业音素引擎（首期用 STT+相似度+LLM 映射星级）

## 4. 实现步骤

### Phase S1 — 内容与 API 骨架

1. 口语剧本 JSON（跟读/问答，挂英语知识点）
2. 表：`speaking_sessions` / `speaking_attempts`
3. API：`start` / `submit-audio`（multipart）/ `session summary`

### Phase S2 — STT + 星级 + 点评

1. 服务端 Whisper（或可配置 STT）转写
2. 文本归一化比对 → 星级算法 + LLM 鼓励文案（无 Key 时用模板降级）
3. 更新英语知识点 mastery 星级
4. 家长 summary 增加口语统计

### Phase S3 — SwiftUI

1. 首页独立「口语陪练」卡片
2. 跟读/问答 UI：示范 TTS、录音、回放、提交、展示点评与星级
3. Info.plist 麦克风用途说明

### Phase S4 — 验收

- 冒烟测试（可用 fixture 音频或 mock STT）
- 双视角验收报告
- 同步 CHANGELOG / features / 本计划状态

## 5. 风险

| 风险 | 缓解 |
|------|------|
| 无 API Key 时无法真 STT | mock/模板路径保证联调；有 Key 走真链路 |
| 二年级发音差异大 | 星级从宽；点评鼓励为主 |
| 隐私 | 默认不长期存原始音频；更新隐私草案 |
| 云端无 Xcode | 同前：源码+后端可测；UI 需 Mac 编译 |

## 6. 验收标准

- 首页独立入口可达
- 跟读、问答各至少 1 条完整路径（示范→录→回放→点评→星级）
- 家长摘要含口语次数或时长
- 无 Key 时服务有明确降级且不崩溃
- 双视角验收报告

## 7. 许可检查清单

请回复：

> 批准按 `docs/plan/20260724_plan_speaking.md` 开始开发。
