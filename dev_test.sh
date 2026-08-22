#!/bin/bash
# 联机本地双人测试：自动打开两个终端窗口分别运行主机和客户端
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJ="/Users/czh/Projects/Clash Legends"

osascript -e "tell application \"Terminal\" to do script \"$GODOT --path \\\"$PROJ\\\" -- --mode=host\""
sleep 2
osascript -e "tell application \"Terminal\" to do script \"$GODOT --path \\\"$PROJ\\\" -- --mode=join --ip=127.0.0.1\""
