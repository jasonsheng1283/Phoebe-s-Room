# Backend — Phoebe's Room API

FastAPI + SQLite。提供知识点、练习会话、批改、星级、家长摘要、相似题生成（本地变式 + 可选 LLM）。

## 运行

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
| GET | `/api/v1/parent/gate` | 家长门禁题目 |
| POST | `/api/v1/parent/gate/verify` | 验证门禁 |
| GET | `/api/v1/parent/summary` | 家长摘要 |
| POST | `/api/v1/questions/generate-similar` | 相似题生成 |

默认家庭码：`phoebe-home`（`.env` 中 `FAMILY_CODE`）。

## 内容

种子数据在仓库 `content/`：`knowledge_points.json`、`seed_questions.json`。启动时导入 SQLite（`data/phoebe.db`）。
