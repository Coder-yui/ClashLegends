#!/usr/bin/env bash
# macOS 本地联机冒烟：自动打开两个终端窗口分别运行主机和客户端。
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

if [[ ! -x "$godot_bin" ]]; then
	echo "找不到 Godot：$godot_bin（可通过 GODOT_BIN 指定）" >&2
	exit 1
fi

launch_terminal() {
	local mode="$1"
	osascript - "$godot_bin" "$project_dir" "$mode" <<'APPLESCRIPT'
on run argv
	set godotPath to item 1 of argv
	set projectPath to item 2 of argv
	set gameMode to item 3 of argv
	set commandText to quoted form of godotPath & " --path " & quoted form of projectPath & " -- --mode=" & gameMode
	if gameMode is "join" then set commandText to commandText & " --ip=127.0.0.1"
	tell application "Terminal" to do script commandText
end run
APPLESCRIPT
}

launch_terminal host
sleep 2
launch_terminal join
