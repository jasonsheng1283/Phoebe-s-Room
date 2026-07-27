# 计划：练习前选择知识点（可多选）

> 状态：已执行（待验收）  
> 日期：2026-07-24  
> 用户确认：1A / 2 多选 / 3B / 4 要全部 / 5A；许可：2026-07-24

## 1. 目标

选科目后增加「选知识点」步骤，再进入模式选择并开始练习；支持多选与「全部知识点」；无题知识点可见但不可选。

## 2. 确认流程

```
首页 → 科目 → 知识点选择（多选 / 全部）→ 模式（巩固/薄弱/习惯）→ 练习会话
```

## 3. 交互规则

| 规则 | 说明 |
|------|------|
| 全部 | 默认提供「全部知识点」；选中时清空具体勾选，行为与现网整科抽题一致 |
| 多选 | 可勾选多个有题知识点；至少选「全部」或 ≥1 个可练知识点才能继续 |
| 无题 | 显示「待练习」，灰态不可勾选 |
| 数学分组 | 上册 / 下册 Section；「全部」置顶 |
| 英语 | 无 semester 时单列表 + 「全部」 |
| 继续按钮 | 标题如「下一步：选练习方式」；未合法选择时禁用 |

## 4. API

`POST /practice/start` 增加可选字段：

```json
"knowledge_point_ids": ["math.g2u.add_2digit_carry", "..."]
```

- 省略 / `null` / `[]`：不按知识点过滤（= 全部）
- 非空：仅从这些 KP 的 approved 题中抽题
- 与现有 `mode`（review / weak / habit）组合：在过滤集合内再按原 mode 排序逻辑抽题
- 若过滤后无题：返回空列表或 400（实现选 **友好空态**：会话可开始但客户端提示「这些知识点暂时没有题目」）

## 5. 改动文件（预估）

| 文件 | 变更 |
|------|------|
| `backend/app/schemas.py` | `StartPracticeRequest.knowledge_point_ids` |
| `backend/app/services/practice.py` | `pick_questions` 支持 KP 过滤 |
| `backend/app/routers/api.py` | 透传参数 |
| `ios/.../APIClient.swift` | startPractice 传 ids |
| `ios/.../HomeView.swift` | 科目 → 新选 KP 页 → ModePicker |
| `ios/.../KnowledgePickerView.swift`（新）或并入 Home | 多选 UI |
| `ios/.../PracticeSessionView.swift` | 接收 selected KP ids |
| `docs/features.md` 等 | 文档同步 |

## 6. Out of Scope

- 按单元折叠动画大改
- 为无题 KP 自动生成题
- 改变三种练习模式语义（仅在选定 KP 子集内生效）

## 7. 验收要点

- 数学：上/下册分组；无题灰显；可选多个有题 KP；可选全部
- 选完后进模式再练习，抽题落在所选 KP
- 薄弱模式在所选子集内仍按低星优先
- 英语多选同样可用

## 8. 许可门禁

已获许可并完成实现。待 Mac 模拟器验收。
