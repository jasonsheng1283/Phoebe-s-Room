#!/usr/bin/env bash
# 兼容旧用法：等价于 restart.sh --foreground
set -euo pipefail
exec "$(cd "$(dirname "$0")" && pwd)/restart.sh" --foreground
