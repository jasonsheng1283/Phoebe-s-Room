#!/usr/bin/env bash
# Mac 本地：启动后端 + 打开 Xcode（iPad 模拟器联调）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

echo "==> 1/3 准备后端依赖"
cd backend
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -q -r requirements.txt
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "已创建 backend/.env（可按需填写 LLM_API_KEY）"
fi

echo "==> 2/3 启动 API :8000（后台）"
# 若已有进程占用则跳过
if curl -sf "http://127.0.0.1:8000/api/v1/health" >/dev/null 2>&1; then
  echo "后端已在运行"
else
  mkdir -p ../data
  nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload \
    > /tmp/phoebe-backend.log 2>&1 &
  echo $! > /tmp/phoebe-backend.pid
  for i in {1..30}; do
    if curl -sf "http://127.0.0.1:8000/api/v1/health" >/dev/null 2>&1; then
      echo "后端就绪 (pid $(cat /tmp/phoebe-backend.pid))"
      break
    fi
    sleep 0.3
  done
  if ! curl -sf "http://127.0.0.1:8000/api/v1/health" >/dev/null 2>&1; then
    echo "后端启动失败，日志：/tmp/phoebe-backend.log" >&2
    exit 1
  fi
fi

echo "==> 3/3 打开 Xcode 工程"
cd "$ROOT/ios"
if [[ ! -d PhoebeRoom.xcodeproj ]]; then
  echo "缺少 PhoebeRoom.xcodeproj" >&2
  exit 1
fi

open PhoebeRoom.xcodeproj

cat <<'TIP'

下一步（在 Xcode）：
1. 顶部运行目的地选 iPad 模拟器（如 iPad (10th generation)）
2. 按 ⌘R 运行
3. 首页 DEBUG 联调条应显示「后端已连通」
4. 可点「改地址」；真机联调改为 http://<Mac局域网IP>:8000/api/v1

可选命令行构建：
  cd ios
  xcodebuild -scheme PhoebeRoom -destination 'platform=iOS Simulator,name=iPad (10th generation)' build

TIP
