# CHANGELOG

本文件记录面向产品与文档的可见变更。格式参考 Keep a Changelog 精神：按日期分组，标注 Added / Changed / Fixed / Removed。

## [Unreleased]

### Added

- 题目可选 `diagram`（angles / symmetry / observe）；DB `diagram_json`；API 透出
- iOS `QuestionDiagramView`（SwiftUI Path）；练习页优先于 `image_asset`
- 种子：角/对称/观察的判断或选择题带 diagram；相似题继承并轻量改参
- 计划 / 讨论 / PRD / 验收：`docs/plan/20260727_plan_diagram_reuse.md` 等
- 可提交的 `ios/PhoebeRoom.xcodeproj` 与 shared scheme
- Mac 一键联调脚本 `ios/scripts/mac-sim-debug.sh`
- DEBUG 联调条（后端健康检查 / 改 Base URL）
- 计划 `docs/plan/20260724_plan_mac_sim.md`
- 二年级数学上下册技能级知识点（38 个）与 `semester` 字段
- 练习前知识点多选（全部 / 多选；数学上线下册分组）
- 数学题型：判断（对/错）、拖放排序、图上定位拖放
- 头脑拓展入口；符号数独 4×4 过关（程序生成、主题轮换、进度同步）
- 数独交互改为仅拖放；待填格虚线+「填」角标（填入后仍保留）
- 全站「阳光小房间 / 软糖色」设计系统（`RoomTheme` v2 + `RoomUI` 组件）
- 题目 `image_asset` 与 `drag_place.background_asset`；Asset Catalog 场景/装饰插画
- UI 计划 / 讨论 / 验收：`docs/plan/20260724_plan_ui_sunny_room.md` 等

### Changed

- 相似题本地变式可对 `diagram` 轻量改参（角高亮轮换、对称形状轮换等）；改参时同步轻改题干
- 练习页：diagram 可带氛围角标；奶油渐变底；横屏/iPad 自适应高度与限宽；首次看图提示；圆柱顶视图标「圆」
- 数学知识点 ID 重构为 `math.g2u.*` / `math.g2l.*`；现有数学种子题挂载迁移
- 知识点列表按上册 / 下册分组展示
- 知识点按内容文件顺序（`sort_order`）排列；无题知识点显示「待练习」弱提示
- `POST /practice/start` 支持 `knowledge_point_ids` 过滤抽题
- 数学去掉填空与应用题；手写改为草稿辅助
- 家长摘要增加符号数独最高关
- 数独去掉点选填格，保留拖符号/拖橡皮
- 首页 / 练习 / 口语 / 拓展 / 星级 / 家长区统一软糖视觉与大触控交互
- 相似题生成继承种子题 `image_asset`（不自动生图）

### Removed

- 旧粗粒度数学知识点 ID（如 `math.addition_within_100` 等）
- 数学 `fill` / `word_problem` 题型（种子已改写）
- 数独「点选符号再点空格」交互

## [0.2.0] - 2026-07-24

### Added

- 英语口语陪练：剧本、API、STT/星级点评、SwiftUI 独立入口与录音回放
- 家长摘要口语统计字段

### Notes

- 合入 `main`；验收改进项 S1～S3 暂不实施

## [0.1.0] - 2026-07-24

### Added

- FastAPI 后端：练习/批改/星级/家长/相似题（`backend/`）
- 内容种子：二年级数学与英语知识点与题目（`content/`）
- SwiftUI iPad 客户端源码（`ios/PhoebeRoom/`）与 XcodeGen 配置
- 隐私政策草案与验收报告（`docs/legal/`、`docs/reviews/`）
- 项目文档架构与 MVP 范围/细节确认存档

### Notes

- 合入 `main`；验收改进项 M1～M5 暂不实施，留作 backlog

## [0.0.1] - 2026-07-24

### Added

- 仓库初始化与文档体系首版
