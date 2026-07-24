# Phoebe's Room

AI 辅助儿童与青少年进行学科知识点强化训练的学习空间。MVP：家庭自用 · 小学二年级 · 数学+英语 · SwiftUI iPad · 先 TestFlight。

## 当前阶段

**开发进行中（主干已落地）。** 后端可本地运行并已冒烟测试；iOS 需在 Mac 用 Xcode/XcodeGen 编译联调。

## 仓库结构

```
backend/     FastAPI + SQLite API
content/     知识点与种子题
ios/         SwiftUI iPad 客户端
docs/        产品与协作文档
```

## 快速开始

### 后端

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
./run.sh
# 测试：python3 scripts/smoke_test.py
```

### iOS

见 [ios/README.md](ios/README.md)（`xcodegen generate` → 打开 `PhoebeRoom.xcodeproj`）。

## 文档

| 文档 | 说明 |
|------|------|
| [docs/BACKGROUND.md](docs/BACKGROUND.md) | 产品定位 |
| [docs/plan/20260724_plan.md](docs/plan/20260724_plan.md) | MVP 计划 |
| [docs/reviews/20260724_acceptance.md](docs/reviews/20260724_acceptance.md) | 验收报告 |
| [docs/features.md](docs/features.md) | 功能列表 |
| [docs/prd/prd.md](docs/prd/prd.md) | PRD 入口 |
