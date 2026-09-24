# 拍摄配方

返回 [工具索引](../README.md)。新单位摄影优先用 [通用模型展台](../viewers/README.md)，以下保留为既有构图或场景的复现配方。

| 脚本 | 用途 |
| --- | --- |
| `capture_*_card_art.gd` | 冰鸟、炮台、士兵、皮克斯、圆盘、墓碑的专用构图；固定路径，可能写正式卡面，先核对输出，不批量运行 |
| `capture_promo_videos.gd` | 宣传场景拍摄 |
| `capture_cover_combat.gd` | 对战封面抓拍（复用 BattlePresentation3D + Tower 搭场景），支持 `--ratio=9x16\|16x9` `--out=<路径>` |
| `capture_rift_arena.gd` | 正式 2D 战场与候选地图斜视角 |
| `capture_rift_arena_v2.gd` | 正式 3D 地图单独预览，支持 `-- --hold` / `-- --inspect`；`-- --motion` 额外保存实战与河道各 36 帧及真实时间 JSON |
| `capture_sun_disc_battle_qa.gd` | 圆盘的实战表现验收 |

Godot 脚本使用 `Godot --path . --script tools/capture/脚本.gd`。摄影需要图形渲染；先读文件顶部参数、输出与退出方式。卡面以原版优先，不因重放历史配方覆盖已有原版素材。

固定卡面配方现在只输出候选图片到素材库按次生成的批次目录，不覆盖 `assets/cards/`。预览和选定后再接入正式卡面。
