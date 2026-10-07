#!/usr/bin/env bash
# 本地一服两端；两个窗口使用同一客户端程序，服务器无窗口。Ctrl-C 清理本组进程。
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
port="${CLASH_PORT:-39152}"
output="$project_dir/ClashLegends-开发素材库/04-中间产物/构建与验证/local-server/$(date +%Y%m%d-%H%M%S)"
if [[ ! -x "$godot_bin" ]]; then
  echo "找不到 Godot：$godot_bin（可通过 GODOT_BIN 指定）" >&2
  exit 1
fi
mkdir -p "$output"
pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT
trap 'exit 130' INT TERM
"$godot_bin" --headless --path "$project_dir" -- --mode=server --port="$port" "$@" > "$output/server.log" 2>&1 &
pids+=("$!")
for ((attempt=0; attempt<100; attempt++)); do
  if grep -q '服务器已启动' "$output/server.log"; then break; fi
  if ! kill -0 "${pids[0]}" 2>/dev/null; then cat "$output/server.log"; exit 1; fi
  sleep 0.1
done
if ! grep -q '服务器已启动' "$output/server.log"; then cat "$output/server.log"; exit 1; fi
for x in 80 540; do
  "$godot_bin" --path "$project_dir" --resolution 432x840 --position "$x,60" -- --mode=join --ip=127.0.0.1 --port="$port" "$@" > "$output/client-$x.log" 2>&1 &
  pids+=("$!")
done
echo "已启动独立服务器与两个客户端。日志：$output"
echo "关闭两个客户端或按 Ctrl-C 结束本组进程。"
wait "${pids[1]}" || true
wait "${pids[2]}" || true
