# 正式游戏资源

这里只保留已接入游戏的素材和运行时依赖。候选、制作中版本、失败尝试和中间产物统一放开发素材库内；分类与迁移规则见 [任务导航](../docs/AGENT_WORKFLOW.md)。

| 目录 | 内容 |
| --- | --- |
| `cards/` | 卡面；CardArt 按 `<card_id>_loading.jpg/png/webp` 自动发现 |
| `skills/` | 主动技能图标；来源与技能映射见 [素材记录](skills/README.md) |
| `units/<card_id>/` | 单位包装场景、模型、动画和纹理 |
| `towers/` | 双方防御塔与水晶的包装场景和素材 |
| `arena/arena_rift_v4.png` | 当前启用的 2D 战场背景 |
| `effects/baron_minion/` | 四兵强化与弹体特效 |
| `audio/units/`、`spells/`、`world/`、`announcer/` | 正式单位、法术、系统建筑与比赛播报音频 |

单位目录名与 CardDB 标识一致。`*_view.tscn` 包装校正缩放、脚底与朝向；定义中的 `visual_scene_path` 或双方 `visual_scene_paths` 指向包装。`source/` 内的 GLB、纹理可能仍被包装引用，不能统一忽略或移走；`.import` 由 Godot 管理。

动画映射与音频事件放逐卡定义，由表现层读取，不驱动伤害、移动或网络状态。音频目录保留来源清单及加工说明；相同声音的不同事件身份不能仅凭哈希合并。卡面优先原生素材，其次复用模型展台摄影，已有卡面不自动覆盖。

制作中的 3D 地图已移至项目根目录的本地工作区 `ClashLegends-开发素材库/03-制作中/3D地图/`，不是正式运行资源；该素材库已被 `.gitignore` 整体忽略。旧实验已移至素材库中间产物。复用地图预览：`python3 tools/dev.py stage --arena --open`。

特殊素材规则见各目录 README 和 [美术流程](../docs/ART_PIPELINE.md)；完整卡牌接入见 [新卡清单](../docs/NEW_CARD_CHECKLIST.md)。
