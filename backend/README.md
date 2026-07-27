# Backend — Phoebe's Room API

FastAPI + SQLite。提供知识点、练习会话、批改、星级、家长摘要、相似题生成（本地变式 + 可选 LLM）。

## 运行

### 一键重启（推荐）

在仓库根目录：

```bash
./backend/restart.sh
```

会先释放 `:8000`，再后台启动；健康检查通过后打印地址。日志：`/tmp/phoebe-backend.log`。

前台运行（当前终端占住）：

```bash
./backend/restart.sh --foreground
# 或
./backend/run.sh
```

在 **Cursor / VS Code** 里：`Cmd+Shift+B`（默认构建任务）或 `Cmd+Shift+P` →「Tasks: Run Task」→ **Phoebe: 重启后端**。

### 手动安装

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

健康检查：`GET http://127.0.0.1:8000/api/v1/health`

## 冒烟测试

```bash
cd backend
python3 scripts/smoke_test.py
```

## 主要接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/health` | 健康检查 |
| GET | `/api/v1/knowledge-points` | 知识点 + 星级 |
| POST | `/api/v1/practice/start` | 开始练习（review/weak/habit） |
| POST | `/api/v1/practice/submit` | 提交作答 |
| POST | `/api/v1/practice/end` | 结束会话 |
| POST | `/api/v1/speaking/start` | 开始口语陪练 |
| POST | `/api/v1/speaking/submit-audio` | 上传录音评测（multipart；可 `mock_transcript`） |
| POST | `/api/v1/speaking/end` | 结束口语会话 |
| GET | `/api/v1/parent/gate` | 家长门禁题目 |
| POST | `/api/v1/parent/gate/verify` | 验证门禁 |
| GET | `/api/v1/parent/summary` | 家长摘要（含口语统计、数独最高关） |
| POST | `/api/v1/questions/generate-similar` | 相似题生成 |
| GET | `/api/v1/extension/activities` | 头脑拓展活动列表 |
| GET | `/api/v1/extension/sudoku/level` | 拉取数独关卡（隐藏答案） |
| POST | `/api/v1/extension/sudoku/clear` | 校验过关并更新进度 |

默认家庭码：`phoebe-home`（`.env` 中 `FAMILY_CODE`）。  
口语 STT：配置 `LLM_API_KEY` 后走 Whisper；`STT_MOCK=true` 时可用 `mock_transcript` 联调。

## 内容

种子数据在仓库 `content/`：`knowledge_points.json`、`seed_questions.json`。启动时导入 SQLite（`data/phoebe.db`）。
