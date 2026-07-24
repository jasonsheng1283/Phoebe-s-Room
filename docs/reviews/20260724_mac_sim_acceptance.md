# 验收说明 — Mac 模拟器联调准备（2026-07-24）

| 字段 | 内容 |
|------|------|
| 计划 | `docs/plan/20260724_plan_mac_sim.md` |
| 云端结果 | 已交付可打开工程与脚本；**无法在本环境实际 ⌘R** |

## 已完成（仓库侧）

| 项 | 状态 |
|----|------|
| `PhoebeRoom.xcodeproj` + scheme 入库 | ✅ |
| `.gitignore` 允许提交工程 | ✅ |
| `mac-sim-debug.sh` 启后端并 open 工程 | ✅ |
| DEBUG 联调条 / 可改 API 地址 | ✅ |
| `ios/README.md` 步骤 | ✅ |

## 需你在 Mac 上确认（约 2 分钟）

1. `./ios/scripts/mac-sim-debug.sh`  
2. Xcode 选 iPad Simulator，⌘R  
3. 首页出现「后端已连通」  
4. 点进数学练习或口语陪练不白屏

若失败，把 Xcode 报错贴回（Signing / 模拟器名称 / 编译错误）。

## 设计视角（简）

- 联调条仅 DEBUG，不污染儿童主路径。  
- 改进（可选）：连通失败时一键「复制启动命令」。
