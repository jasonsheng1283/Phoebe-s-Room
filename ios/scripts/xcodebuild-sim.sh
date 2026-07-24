#!/usr/bin/env bash
# 仅命令行构建（需已安装 Xcode + 模拟器运行时）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT/ios"

DEST="${1:-platform=iOS Simulator,name=iPad (10th generation)}"
echo "Building for: $DEST"
xcodebuild \
  -project PhoebeRoom.xcodeproj \
  -scheme PhoebeRoom \
  -configuration Debug \
  -destination "$DEST" \
  -derivedDataPath DerivedData \
  build | xcbeautify 2>/dev/null || xcodebuild \
  -project PhoebeRoom.xcodeproj \
  -scheme PhoebeRoom \
  -configuration Debug \
  -destination "$DEST" \
  -derivedDataPath DerivedData \
  build
