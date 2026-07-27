# 计划：全站「阳光小房间 / 软糖色」UI 重设计

> 状态：已执行（待真机目视验收）  
> 日期：2026-07-24  
> 用户确认：范围 1A / 图形 2B / 风格「阳光小房间 · 软糖色」；许可：2026-07-24

## 1. 目标

把 Phoebe's Room 全站升级为面向小学二年级的「阳光小房间 / 软糖色」体验：统一设计系统、大触控、轻反馈；题内图形改为 Asset Catalog 静态插画。

## 2. 复述结论

| 项 | 结论 |
|----|------|
| 范围 | 首页、选知识点、练习方式、做题、口语、头脑拓展/数独、星级、家长区 |
| 题内图形 | 静态插画；`image_asset` + `interaction.background_asset` |
| 风格 | 奶油墙 + 软粉/柠檬/薄荷绿/天蓝；大圆角；rounded 字体 |
| 非目标 | 不改练习/批改逻辑；不做像素 drop；不自动生图；不加成瘾激励 |

## 3. 实现摘要（已完成）

1. `RoomTheme` v2 + `ios/PhoebeRoom/Components/RoomUI.swift`
2. 后端/种子/iOS 透出 `image_asset`；`drag_place` 展示 `background_asset`
3. 各主界面皮肤重做；家长区同色板偏安静
4. 验收：`docs/reviews/20260724_ui_sunny_room_acceptance.md`；文档已同步

## 4. 回写

- 冒烟：`backend/scripts/smoke_test.py` 通过（含 `background_asset` 断言）
- 真机/模拟器目视仍为 backlog
