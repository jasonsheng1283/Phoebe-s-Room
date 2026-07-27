# 计划：数学题型改为选择/判断，并支持图形拖放

> 状态：已执行（待验收）  
> 日期：2026-07-24  
> 用户确认：1A / 2A / 3C / 4C / 5B / 6A；许可：2026-07-24

## 1. 目标

数学作答主路径改为 **选择题 + 判断题（对/错）**；去掉数学填空与应用题题型。本期实现两类真拖放：**图上定位（drag_place）** 与 **排序（drag_sort）**，优先服务角、观察物体、轴对称、平移等图形向知识点。手写保留为草稿辅助。英语不动。

## 2. 复述结论

| 项 | 结论 |
|----|------|
| 数学题型 | `choice`、`true_false`、`drag_place`、`drag_sort` |
| 废弃（数学） | `fill`、`word_problem`；种子题改写或替换 |
| 判断 | 仅「对」「错」两按钮；题干为陈述句 |
| 拖放 | 本期真交互：图上拖到槽位 + 条目排序 |
| 手写 | 保留草稿区，不作为最终答案通道（数学） |
| 英语 | 拼读/听力不变 |

> 说明：3C 要「图上定位」、4C 要「排序」——计划按 **两种都做**。若你只要其中一种，许可时请注明。

## 3. 题型与数据结构

### 3.1 choice（已有）

不变：`options[]` + `answer` 为选项文案。

### 3.2 true_false（新）

- `options`: 固定 `["对", "错"]`（也可服务端/客户端写死）
- `answer`: `"对"` 或 `"错"`
- 题干示例：`46 + 7 = 53。`

### 3.3 drag_sort（新）

```json
{
  "type": "drag_sort",
  "stem": "把下面的数从小到大排一排。",
  "options": [],
  "interaction": {
    "kind": "sort",
    "items": [
      {"id": "a", "label": "58"},
      {"id": "b", "label": "85"},
      {"id": "c", "label": "35"}
    ]
  },
  "answer": "c,a,b"
}
```

提交答案：有序 id，逗号分隔。

### 3.4 drag_place（新）

不用外部照片资产（首期），用 **SwiftUI 程序化画布**（角、对称轴、方位示意）：

```json
{
  "type": "drag_place",
  "stem": "把「直角」标签拖到正确的角上。",
  "interaction": {
    "kind": "place",
    "scene": "angles_three_v1",
    "tokens": [
      {"id": "right", "label": "直角"},
      {"id": "acute", "label": "锐角"}
    ],
    "slots": [
      {"id": "s1", "label": "角1"},
      {"id": "s2", "label": "角2"},
      {"id": "s3", "label": "角3"}
    ]
  },
  "answer": "{\"s2\":\"right\"}"
}
```

- `scene`：客户端内置场景 id（角度三选一、对称贴纸位、观察方位等）
- 提交：JSON 映射 `slot_id -> token_id`（可只填部分槽；判分按题目定义的必填槽）

存储：SQLite `questions` 增加 `interaction_json TEXT`（或把 interaction 塞进现有字段扩展）；API `QuestionPublic` 增加可选 `interaction`。

## 4. 内容改动

| 动作 | 说明 |
|------|------|
| 改写现有数学种子 | fill → choice 或 true_false；word_problem → choice（给选项）或 true_false |
| 新增判断种子 | 至少覆盖加减、乘除含义各若干 |
| 新增拖放种子 | 首批 KP：`angle_right` / `angle_acute_obtuse` / `observe_object` / `symmetry` / `translation`；各 ≥1 道 place 或 sort |
| 相似题 | 本地变式去掉 fill/word_problem 分支；true_false / drag 可先不做 LLM 变式或仅复制题干微调 |

## 5. 客户端

- `true_false`：大号「对」「错」按钮（二年级友好）
- `drag_sort`：SwiftUI `draggable` / `dropDestination`（iOS 17+）排序列表
- `drag_place`：场景画布 + 可拖 token + 槽位高亮；松手落槽
- 手写：仍可打开草稿，**不参与提交**
- 首页文案：「选择 · 判断 · 拖一拖」

## 6. 后端

- `QuestionType` 扩展；判分：true_false 同字符串；drag_sort 有序比对；drag_place JSON 规范化后比对
- `pick_questions` / 导入支持 `interaction_json`
- 冒烟覆盖判断 + 至少一种拖放提交

## 7. 改动文件（预估）

- `content/seed_questions.json`
- `backend/app/schemas.py`、`db.py`、`grading.py`、`similar.py`、`practice.py`
- `ios/.../Models.swift`、`PracticeSessionView.swift`
- 新组件：`TrueFalseAnswerView`、`DragSortView`、`DragPlaceView` + 场景绘制
- 文档：features / PRD / BACKGROUND 题型表 / CHANGELOG / 计划

## 8. Out of Scope

- 照片级几何题资源包、Apple Pencil 几何作图
- 英语题型变更
- 填空 OCR / 应用题过程分

## 9. 风险与策略

- **图上定位**依赖场景实现量：首期 2～3 个内置 `scene`，可复用到多题
- 拖放在模拟器可用鼠标；真机/iPad 手指拖放需你本地验收
- 旧库中 fill/word_problem 题：导入时覆盖种子；变式旧题可清理或忽略

## 10. 许可门禁

已获许可并完成主干实现。排序交互首期用上下箭头（ScrollView 内更稳）；图上定位为程序化场景 + 标签拖到槽位。待模拟器验收。
