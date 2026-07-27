# 讨论：题内非文本图形复用（静态插画 + iOS Path diagram）

> 日期：2026-07-27  
> 状态：已确认并已实现，验收关闭  
> 计划：`docs/plan/20260727_plan_diagram_reuse.md`

## 背景

相似题/变式时插画产能不足；不宜每题 AI/人工生新图。需区分「氛围插画」与「教学几何」。

## 确认结论

| 项 | 结论 |
|----|------|
| 痛点 | 相似题变式时插画产能不够 |
| 方案 | 双轨：静态 `image_asset` 复用 + 可选 `diagram` 由 iOS Path 绘制 |
| 第一批 diagram | 角 / 轴对称 / 观察物体 |
| 题型范围 | **仅** `choice` / `true_false`；`drag_place` 底图不动 |
| 相似题 × 插画 | **不**把「无新插画也可上架」写成硬性产品规则；仍宜继承种子 `image_asset` |
| 相似题 × diagram | **允许**本地 / `similar` 改 diagram 参数 |
| 渲染端 | 仅 iOS Path；不做后端出图、不做 SVG 管线、不做 AI 生图 |
| 显示优先级 | 有 `diagram` → Path；否则 `image_asset`；都无 → 缺图占位 |

## 非目标

- 后端出图缓存 / SVG 模板 / AI 生图
- 改 `drag_place` / `drag_sort` 场景模型
- 英语题 diagram
- 改批改主逻辑
