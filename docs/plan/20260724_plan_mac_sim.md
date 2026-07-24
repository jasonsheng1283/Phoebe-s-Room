# 实现计划 — Mac 模拟器联调就绪

| 字段 | 内容 |
|------|------|
| 日期 | 2026-07-24 |
| 状态 | **In Progress**（云端无法真跑模拟器；交付可打开工程 + 一键脚本） |
| 诉求 | 「Mac 上跑通模拟器联调」（原 M1 / S1） |
| 关联验收 | `docs/reviews/20260724_acceptance.md`、`docs/reviews/20260724_speaking_acceptance.md` |

## 目标

让开发者在 Mac 上用最少步骤：启动后端 → 打开 Xcode → iPad 模拟器 ⌘R → 首页显示后端已连通并可练题/口语。

## 改动范围

| 路径 | 内容 |
|------|------|
| `ios/PhoebeRoom.xcodeproj/` | 可提交的 Xcode 工程 + shared scheme |
| `ios/PhoebeRoom/Config/APIConfig.swift` | 联调 Base URL |
| `ios/PhoebeRoom/Views/DevServerBanner.swift` | DEBUG 健康检查条 |
| `ios/scripts/mac-sim-debug.sh` | 一键后端 + 打开工程 |
| `ios/scripts/xcodebuild-sim.sh` | 可选命令行构建 |
| `.gitignore` | 不再忽略整个 xcodeproj |
| `ios/README.md` | 联调步骤 |

## 云端限制

本环境无 `xcodebuild` / 模拟器，**无法在此验证 ⌘R**；以工程完整性 + 后端健康检查 + 文档脚本为交付，需你在 Mac 上点一次确认。

## 验收标准（Mac）

1. `./ios/scripts/mac-sim-debug.sh` 后 Xcode 打开且后端 `/health` 为 ok  
2. 选 iPad Simulator，⌘R 启动成功  
3. 首页联调条「后端已连通」  
4. 数学练习与口语入口可进入（口语需麦克风权限）
