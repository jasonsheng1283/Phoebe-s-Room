#!/usr/bin/env bash
# 一键重启 Phoebe 后端（释放 :8000 后重新启动）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
PORT="${PHOEBE_PORT:-8000}"
LOG="${PHOEBE_BACKEND_LOG:-/tmp/phoebe-backend.log}"
PID_FILE="${PHOEBE_BACKEND_PID:-/tmp/phoebe-backend.pid}"
FOREGROUND="${1:-}"

export PATH="${HOME}/.local/bin:${PATH}"

echo "==> 停止占用 :${PORT} 的进程"
if command -v lsof >/dev/null 2>&1; then
  if lsof -tiTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    lsof -tiTCP:"${PORT}" -sTCP:LISTEN | xargs kill 2>/dev/null || true
    sleep 0.4
    # 仍占用则强杀
    if lsof -tiTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
      lsof -tiTCP:"${PORT}" -sTCP:LISTEN | xargs kill -9 2>/dev/null || true
      sleep 0.2
    fi
    echo "已停止旧进程"
  else
    echo "端口空闲"
  fi
elif [[ -f "${PID_FILE}" ]]; then
  kill "$(cat "${PID_FILE}")" 2>/dev/null || true
  rm -f "${PID_FILE}"
fi

if [[ ! -d .venv ]]; then
  echo "==> 创建虚拟环境"
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -q -r requirements.txt
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "已创建 .env（可按需填写 LLM_API_KEY）"
fi

mkdir -p ../data

if [[ "${FOREGROUND}" == "--foreground" || "${FOREGROUND}" == "-f" ]]; then
  echo "==> 前台启动 http://127.0.0.1:${PORT} （Ctrl+C 停止）"
  exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT}" --reload
fi

echo "==> 后台启动 API"
nohup uvicorn app.main:app --host 0.0.0.0 --port "${PORT}" --reload \
  > "${LOG}" 2>&1 &
echo $! > "${PID_FILE}"

for _ in {1..40}; do
  if curl -sf "http://127.0.0.1:${PORT}/api/v1/health" >/dev/null 2>&1; then
    echo "✅ 后端已就绪  http://127.0.0.1:${PORT}/api/v1/health"
    echo "   pid $(cat "${PID_FILE}")  日志 ${LOG}"
    exit 0
  fi
  sleep 0.25
done

echo "❌ 启动失败，最近日志：" >&2
tail -n 40 "${LOG}" >&2 || true
exit 1
