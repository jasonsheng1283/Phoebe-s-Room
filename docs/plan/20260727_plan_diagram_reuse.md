# 计划：题内 diagram（iOS Path）+ 插画复用

> 状态：已执行并验收关闭  
> 日期：2026-07-27  
> 讨论：`docs/discussions/20260727_diagram_reuse.md`  
> 用户确认：三类 KP / 不写死无新图上架规则 / 允许 similar 改 diagram / 仅判断与选择；许可执行：2026-07-27

## 1. 目标

缓解相似题变式时的插画产能压力：氛围图继续静态复用；教学几何用参数化 `diagram`，由 iOS Path 运行时绘制，变式只改参数。

## 2. 复述结论（已确认）

| 项 | 结论 |
|----|------|
| diagram 覆盖 | `angles` / `symmetry` / `observe` |
| 题型 | 仅 `choice`、`true_false` |
| drag_place | 底图与槽位不动 |
| 插画规则 | 不写死「无新图也可上架」；实践上相似题仍继承 `image_asset` |
| diagram 变式 | 允许 `_local_similar` / LLM 路径改参数 |
| 非目标 | 后端出图、SVG、AI 生图、英语、改批改 |

## 3. 实现摘要（已完成）

1. DB `diagram_json`；schema / practice 透出；seed upsert  
2. 种子：`q_math_angle_02/03`、`q_math_observe_02`、`q_math_sym_02`  
3. similar：继承 + 轻量改参 + 题干对齐  
4. iOS：`DiagramSpec` + `DiagramViews.swift`；氛围角标 / 奶油底 / 横屏自适应  
5. 冒烟 + iPad `xcodebuild` 通过；验收关闭  

## 4. 回写

- 验收：`docs/reviews/20260727_diagram_reuse_acceptance.md`（已关闭）  
- PRD：`docs/prd/diagram_reuse_20260727.md`  
