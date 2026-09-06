# 开发工具

- `capture/`：没有现成卡面资源时使用的卡面与宣传素材摄影脚本，不参与运行时；四类兵线和墓碑使用各自脚本。已有 CommunityDragon 或其他正式卡面时不需要运行摄影脚本。
- `demos/`：需要实际渲染和人工观察的演示场景。
- `arena/build_rift_arena.py`：通过 Blender 重建峡谷竞技场的可编辑源文件与运行时 GLB；规格和参考见 `assets/arena/rift_arena/README.md`。
- `capture/capture_rift_arena.gd`：使用实际游戏渲染器验证当前旧背景的 gameplay 画面，并单独输出候选 3D 地图的斜视角模型预览。
- `run_local_multiplayer.sh`：macOS 本地主机/客户端双端冒烟；可用 `GODOT_BIN` 覆盖 Godot 路径。

所有 Godot 命令都从项目根目录运行，具体参数见各脚本顶部注释。
