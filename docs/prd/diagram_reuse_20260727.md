# PRD：题内 diagram（参数化教学图）

| 字段 | 内容 |
|------|------|
| 标题 | 题内 diagram 复用与 iOS Path 渲染 |
| 状态 | Approved — 主干已实现并验收关闭 |
| 作者 | Phoebe's Room |
| 日期 | 2026-07-27 |
| 关联讨论 | `docs/discussions/20260727_diagram_reuse.md` |
| 关联计划 | `docs/plan/20260727_plan_diagram_reuse.md` |

## 1. 背景与目标

相似题/变式时插画产能不足。目标：氛围插画静态复用；教学几何用 `diagram` 参数由客户端 Path 绘制，变式只改参数。

成功标准：判断/选择题可带 `diagram`；练习页优先显示 Path 图；相似题可继承并轻量改参；`drag_place` 不变；冒烟通过。

## 2. 用户与场景

- 主用户：二年级孩子做数学判断/选择图形题
- 场景：练习中看到角/对称/观察物体的清晰示意图；相似题无需新插画也能看到对齐题意的教学图
- 非场景：拖放场景底图程序化、英语 diagram、AI 生图、后端出图

## 3. 范围

### 3.1 In Scope

- 字段 `diagram` / DB `diagram_json`
- kind：`angles` / `symmetry` / `observe`
- 题型：仅 `choice` / `true_false`
- iOS Path 渲染；显示优先级 diagram > image_asset > 占位
- 相似题继承 + 本地轻量改参

### 3.2 Out of Scope

- 后端渲染缓存、SVG 管线、AI 生图
- `drag_place` / `drag_sort` 改模型
- 硬性规定「无新插画也可上架」

## 4. 用户故事

| ID | 作为… | 我想… | 以便… | 优先级 | 验收标准 | 状态 |
|----|-------|-------|-------|--------|----------|------|
| R-001 | 孩子 | 做角/对称/观察的判断或选择题时看到示意图 | 理解题意 | P1 | Path 图显示 | ✅ |
| R-002 | 内容/系统 | 相似题改 diagram 参数而非新画插画 | 缓解产能 | P1 | similar 返回 diagram | ✅ |

## 5. 功能说明

题目 JSON 可选 `diagram` 对象；API 透出；客户端 `QuestionDiagramView` 按 kind 绘制。有 diagram 时不展示同题 `image_asset`（保留字段作降级/氛围备份）。

## 6. 非功能

- 离线可用（逻辑在 App）
- 软糖色、大字号标签
- 儿童友好，无成瘾激励

## 7. 验收

见 `docs/reviews/20260727_diagram_reuse_acceptance.md`
