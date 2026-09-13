# 非运行时素材归档

本目录有 `.gdignore`，不参与 Godot 导入。它保存被当前素材替代的实验源件与出处，不接受 `res://assets/archive/` 运行时引用。

- `2026-09-13/baron_buff/`：第一版英雄男爵符文适配，已被 `assets/effects/baron_minion/` 的小兵专用资源替代。仍复用的 overlay shader 已移入当前目录；旧场景/脚本仅供追溯，里面的原始路径不是可执行入口。
- `2026-09-13/rift_arena/`：旧四象限图集、生成提示与未启用的背景 shader 实验。当前候选 3D 地图仍在 `assets/arena/rift_arena/`，正式比赛继续使用 2D 背景。

归档不保留可再生 `.import` sidecar。不要把仍在使用的模型纹理、源 GLB、Blender 文件、事件清单或工作台试听音频当作中间垃圾移入这里。
