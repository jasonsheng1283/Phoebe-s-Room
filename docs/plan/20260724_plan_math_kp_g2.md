# 计划：二年级数学上下册技能级知识点重构

> 状态：已执行（待验收确认）  
> 日期：2026-07-24  
> 关联：F-011；用户确认 1A / 2B / 3B / 4B / 5A；许可：2026-07-24

## 1. 目标

以人教版小学二年级上下册为骨架，将数学知识点重构为**技能级**目录；JSON/API/客户端支持 `semester`；迁移现有数学种子题挂载的 `knowledge_point_id`。本次**不为新知识点补种子题**。

## 2. 范围

### In Scope

- 重写 `content/knowledge_points.json` 中数学部分（技能级 + `semester`）
- 数学旧 ID → 新 ID 映射，并更新 `content/seed_questions.json` 中已有数学题的 `knowledge_point_id`
- SQLite / 导入逻辑增加 `semester`；API schema 与 iOS `KnowledgePoint` 同步
- 知识点列表 UI 可按上/下册分组或展示册别标签（最小改动）
- 清理本地库中已废弃的旧数学知识点（避免列表残留）
- 文档：features / PRD 增量 / CHANGELOG / 讨论存档

### Out of Scope

- 为新增知识点编写种子题
- 英语知识点改动
- 教材版本绑定（仅用人教版作通识骨架，不展示「人教版」强绑定文案）
- 完整知识图谱可视化、诊断引擎

## 3. 拟议知识点清单（技能级）

`semester`: `upper` = 上册，`lower` = 下册。

### 3.1 上册（upper）

| id | name | prerequisites（摘要） |
|----|------|----------------------|
| `math.g2u.length_cm` | 认识厘米 | — |
| `math.g2u.length_m` | 认识米与米厘米换算 | `length_cm` |
| `math.g2u.length_estimate` | 长度估测与比较 | `length_m` |
| `math.g2u.add_2digit_no_carry` | 两位数加两位数（不进位） | — |
| `math.g2u.add_2digit_carry` | 两位数加两位数（进位） | `add_2digit_no_carry` |
| `math.g2u.sub_2digit_no_borrow` | 两位数减两位数（不退位） | — |
| `math.g2u.sub_2digit_borrow` | 两位数减两位数（退位） | `sub_2digit_no_borrow` |
| `math.g2u.add_sub_mix` | 连加连减与加减混合 | `add_2digit_carry`, `sub_2digit_borrow` |
| `math.g2u.word_add_sub` | 100以内加减应用题 | `add_sub_mix` |
| `math.g2u.angle_right` | 认识直角 | — |
| `math.g2u.angle_acute_obtuse` | 锐角与钝角 | `angle_right` |
| `math.g2u.mult_meaning` | 乘法的初步认识 | — |
| `math.g2u.mult_table_2_5` | 2～5 的乘法口诀 | `mult_meaning` |
| `math.g2u.mult_table_6` | 6 的乘法口诀 | `mult_table_2_5` |
| `math.g2u.observe_object` | 观察物体（从不同位置） | — |
| `math.g2u.mult_table_7_9` | 7～9 的乘法口诀 | `mult_table_6` |
| `math.g2u.mult_add_sub` | 乘加、乘减 | `mult_table_7_9` |
| `math.g2u.mult_word` | 表内乘法解决问题 | `mult_add_sub` |
| `math.g2u.time_hour_minute` | 时、分的认识 | — |
| `math.g2u.time_read` | 读写几时几分 | `time_hour_minute` |
| `math.g2u.combination` | 简单搭配（数学广角） | — |

### 3.2 下册（lower）

| id | name | prerequisites（摘要） |
|----|------|----------------------|
| `math.g2l.data_collect` | 数据收集与分类整理 | — |
| `math.g2l.data_table` | 简单统计表与条形图入门 | `data_collect` |
| `math.g2l.div_equal_share` | 平均分与除法含义 | `math.g2u.mult_meaning` |
| `math.g2l.div_table_2_6` | 用 2～6 口诀求商 | `div_equal_share`, `math.g2u.mult_table_6` |
| `math.g2l.symmetry` | 轴对称（图形的运动） | — |
| `math.g2l.translation` | 平移 | — |
| `math.g2l.div_table_7_9` | 用 7～9 口诀求商 | `div_table_2_6`, `math.g2u.mult_table_7_9` |
| `math.g2l.div_word` | 表内除法解决问题 | `div_table_7_9` |
| `math.g2l.mixed_ops` | 混合运算（含小括号） | `math.g2u.add_sub_mix` |
| `math.g2l.div_with_remainder` | 有余数的除法 | `div_table_7_9` |
| `math.g2l.div_remainder_word` | 有余数除法解决问题 | `div_with_remainder` |
| `math.g2l.num_within_1000_read` | 千以内数的读法写法 | — |
| `math.g2l.num_within_1000_compare` | 千以内数的大小比较 | `num_within_1000_read` |
| `math.g2l.num_within_10000` | 万以内数的认识 | `num_within_1000_compare` |
| `math.g2l.mass_g` | 认识克 | — |
| `math.g2l.mass_kg` | 认识千克与克千克关系 | `mass_g` |
| `math.g2l.reasoning` | 简单推理（数学广角） | — |

> 清单在许可后可按你的反馈微调；执行时以确认版为准。

## 4. 旧 ID 迁移（现有种子题）

| 旧 knowledge_point_id | 题目 | 新 knowledge_point_id |
|-----------------------|------|------------------------|
| `math.addition_within_100` | `q_math_add_01`（23+15 不进位） | `math.g2u.add_2digit_no_carry` |
| `math.addition_within_100` | `q_math_add_02`（46+7 进位） | `math.g2u.add_2digit_carry` |
| `math.subtraction_within_100` | `q_math_sub_01`（50-18 退位） | `math.g2u.sub_2digit_borrow` |
| `math.subtraction_within_100` | `q_math_sub_02`（72-9 退位） | `math.g2u.sub_2digit_borrow` |
| `math.word_problem_add_sub` | `q_math_wp_01` / `02` | `math.g2u.word_add_sub` |
| `math.place_value` | `q_math_place_01`（67 的数位） | `math.g2l.num_within_1000_read`（二年级下册数的认识技能；题干仍为两位数） |

废弃旧 ID：`math.addition_within_100`、`math.subtraction_within_100`、`math.word_problem_add_sub`、`math.place_value`、`math.measurement_length`（无种子题挂载，直接删除）。

**影响说明**：已有练习记录 / mastery 挂在旧 ID 上会失效或需清理；家庭自用 MVP 可接受「重建 mastery」。导入时删除不在新目录中的数学知识点及其 mastery（仅 math 旧 ID）。

## 5. 技术方案

1. **内容**：`knowledge_points.json` 数学条目增加 `"semester": "upper"|"lower"`；英语条目可省略或 `null`（schema 默认 optional）。
2. **DB**：`knowledge_points` 增加 `semester TEXT`；启动导入 upsert；对 math 执行「新集合同步」：插入/更新新点，删除 JSON 中不存在的旧 math 点（及关联 mastery；题目已改挂新 ID）。
3. **API**：`KnowledgePoint.semester: str | None`；`list_knowledge_points` 返回该字段。
4. **iOS**：`KnowledgePoint.semester`；知识点列表按册分组或显示「上册/下册」小标签。
5. **测试**：更新 smoke / 任何硬编码旧 math KP ID 的脚本。

## 6. 改动文件（预估）

| 文件 | 变更 |
|------|------|
| `content/knowledge_points.json` | 数学技能级目录 + semester |
| `content/seed_questions.json` | 数学题 KP ID 迁移 |
| `backend/app/db.py` | 列 semester；导入与旧点清理 |
| `backend/app/schemas.py` | semester 字段 |
| `backend/app/services/practice.py` | 读出 semester |
| `ios/.../Models.swift` | semester |
| `ios/.../ParentAndKnowledgeViews.swift` | 册别展示（最小） |
| `backend/scripts/smoke_test.py` | 如有旧 ID 引用则更新 |
| `docs/features.md` 等 | 文档同步 |

## 7. 验收要点

- 知识点 API 返回二年级数学上/下册技能点，含 `semester`
- 旧 5 个粗粒度 ID 不再出现；现有数学种子题可正常抽题
- iOS 知识点页可见册别
- 英语知识点与口语脚本不受影响

## 8. 许可门禁

已获许可并完成实现（内容 + 后端 semester/清理 + iOS 册别分组 + 文档同步）。待验收反馈。
