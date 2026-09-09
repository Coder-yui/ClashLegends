# 美术资源目录

资源使用英文 `snake_case`，单位目录名与 CardDB `card_id` 一致。任务先通过 `docs/AGENT_WORKFLOW.md` 路由；本文只规定归档和命名。

```text
assets/
  audio/units/<card_id>/                    单位攻击、技能等短音效
  arena/arena_rift_v4.png                 当前 720×1400 运行时 2D 背景
  arena/rift_arena/rift_arena.tscn        候选 720×1280 3D 地图（暂不启用）
  arena/rift_arena/source/               Blender 可编辑源文件（不自动导入）
  cards/<card_id>_loading.jpg|png|webp     CardArt 自动发现
  units/<card_id>/
    README.md                              仅角色存在素材特例时添加
    source/                                GLB、纹理等源文件
    <card_id>_view.tscn                    通用运行时包装场景
  towers/<type>/source/                    塔/水晶源素材
  towers/<type>/*_view.tscn                双方包装场景
```

同一单位双方模型使用 `visual_scene_paths = [order/blue, chaos/red]`；单模型使用 `visual_scene_path`。原始素材留在 `source/`，包装场景只校正缩放、脚底、朝向或必要的素材过滤。不要手改 `.import`，不要让素材脚本驱动权威战斗。

## 卡面

`CardArt` 按 jpg → png → webp 自动发现 `assets/cards/<card_id>_loading.*`，手牌与 Deck Builder 使用统一卡框裁剪；无需在 CardDB 写图片路径。现有可选卡均已有卡面。没有现成卡面时，可参考 `tools/capture/` 中的摄影脚本；四类兵线和墓碑使用各自脚本。这些脚本只生成图片，不参与运行时。

卡面资源获取遵循“现成资源优先”：英雄先从 CommunityDragon 下载基础皮肤 Loading Screen；没有原生图但有模型时拍 3D 模型；图像和模型都没有时再用 AI 生成。已有卡面不得被后续拍摄或 AI 结果覆盖。

## 当前特殊目录

- `arena/rift_arena/`：候选地图的规格、Blender 重建/导出和实际渲染验收见该目录 README；当前运行时仍使用 `arena_rift_v4.png`，候选地形仅影响独立预览。
- `units/gnar/`：小/大双模型、加法动画合成和网格过滤；读该目录 README。
- `units/tombstone/`：包装场景含独立雾效脚本。
- `towers/`：TowerModel3D 管理材质阶段、碎块和废墟；仍由 2D Tower 决定血量/死亡。

普通近战不要阅读角色特例；按 `ART_PIPELINE.md` 与 `MELEE_3D_INTEGRATION.md` 即可。远程再读 `RANGED_3D_INTEGRATION.md`。

## 音频

短促、重复播放的战斗音效放在 `assets/audio/units/<card_id>/`，卡牌的音频池在 CardDB `audio` 中登记并由 `GameAudioManager` 消费。挥击声按攻击动画段配置，真实命中声只由权威伤害成功事件触发；音频不得反向驱动伤害或动画状态。背景音乐与 UI 音效分别使用 `Music`、`UI` 总线，战斗音效使用 `Combat` 总线。
