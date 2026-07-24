# iOS 客户端（SwiftUI / iPad）

本目录为 **Phoebe's Room** 的 iPad 客户端源码。当前云端环境无 Xcode，无法在此完成真机编译；请在 Mac 上打开工程。

## 快速开始

### 方式 A：用 XcodeGen 生成工程（推荐）

```bash
brew install xcodegen
cd ios
xcodegen generate
open PhoebeRoom.xcodeproj
```

### 方式 B：手动创建 Xcode 工程

1. Xcode → New iOS App（SwiftUI，Swift，iPad only）
2. 将 `PhoebeRoom/` 下源文件加入 Target
3. 使用本目录 `Info.plist`（或合并 ATS / 方向设置）
4. Deployment Target ≥ iOS 17，`TARGETED_DEVICE_FAMILY = 2`（iPad）

## 联调后端

1. 在仓库根或 `backend/` 启动 API：

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # 可按需填 LLM_API_KEY
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

2. 模拟器默认请求 `http://127.0.0.1:8000/api/v1`（见 `Services/APIClient.swift`）。
3. 真机请改为 Mac 局域网 IP，并确保 ATS 允许本地网络（已在 Info.plist 打开 `NSAllowsLocalNetworking`）。

## 已实现界面

- 首页：Phoebe's Room 品牌 + 数学/英语入口 + **口语陪练独立入口**
- 三模式：课后巩固 / 薄弱专项 / 日常习惯
- 练习流：点选、输入、手写确认、英语 TTS 播放、解析与星级
- 口语：示范 TTS、录音、回放、提交评测、鼓励点评与星级
- 知识点星级列表
- 家长门禁 + 进度摘要（含口语统计）

## TestFlight

在 Apple Developer 配置 Bundle ID、证书与 App Store Connect 后，Archive → Distribute → TestFlight。隐私文案见 `docs/legal/privacy_draft.md`。
