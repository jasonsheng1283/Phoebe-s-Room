# iOS 客户端（SwiftUI / iPad 优先）

仓库已包含 **`PhoebeRoom.xcodeproj`**，Mac 上可直接打开，无需先跑 XcodeGen。

> 云端 Linux 无法运行 Xcode / 模拟器；联调请在本机 Mac 执行。

## 一键联调（推荐）

在 **Mac** 终端：

```bash
chmod +x ios/scripts/mac-sim-debug.sh
./ios/scripts/mac-sim-debug.sh
```

脚本会：

1. 准备 `backend` 虚拟环境并启动 `http://127.0.0.1:8000`
2. 打开 `ios/PhoebeRoom.xcodeproj`

然后在 Xcode：

1. 运行目的地选 **iPad 模拟器**（也可用 iPhone 模拟器做冒烟）
2. ⌘R 运行
3. 首页 DEBUG 条应显示 **后端已连通**
4. 练习数学/英语/口语陪练；口语需允许麦克风

### 命令行构建（可选）

```bash
chmod +x ios/scripts/xcodebuild-sim.sh
./ios/scripts/xcodebuild-sim.sh
# 或指定机型：
./ios/scripts/xcodebuild-sim.sh 'platform=iOS Simulator,name=iPad Air 11-inch (M2)'
```

查看本机可用模拟器：`xcrun simctl list devices available`

## 联调地址

| 场景 | Base URL |
|------|----------|
| 模拟器 | `http://127.0.0.1:8000/api/v1`（默认） |
| 真机 | `http://<Mac局域网IP>:8000/api/v1`（首页联调条「改地址」） |

后端：

```bash
cd backend
source .venv/bin/activate   # 若已按脚本创建
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 重新生成工程（可选）

若你更习惯 XcodeGen：

```bash
brew install xcodegen
cd ios && xcodegen generate
```

注意：手改 `project.pbxproj` 后与 `project.yml` 可能不一致，二选一维护即可。

## 已实现界面

- 首页：品牌 + 数学/英语 + **口语陪练** + DEBUG 联调条
- 三模式练习、手写确认、TTS、星级
- 口语：示范 / 录音 / 回放 / 点评星级
- 家长门禁与摘要

## TestFlight

见 `docs/legal/privacy_draft.md`；需 Apple Developer 账号 Archive。
