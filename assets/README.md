# 美术资源目录

资源使用英文 `snake_case`，单位目录名与 CardDB `card_id` 一致。任务先通过 `docs/AGENT_WORKFLOW.md` 路由；本文只规定归档和命名。

```text
assets/
  arena/arena_rift_v4.png                 当前 720×1400 背景
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

`CardArt` 按 jpg → png → webp 自动发现 `assets/cards/<card_id>_loading.*`，手牌与 Deck Builder 使用统一卡框裁剪；无需在 CardDB 写图片路径。现有可选卡均已有卡面。四类兵线和墓碑的摄影工具位于 `tools/capture/`，只生成图片，不参与运行时。

## 当前特殊目录

- `units/gnar/`：小/大双模型、加法动画合成和网格过滤；读该目录 README。
- `units/tombstone/`：包装场景含独立雾效脚本。
- `towers/`：TowerModel3D 管理材质阶段、碎块和废墟；仍由 2D Tower 决定血量/死亡。

普通近战不要阅读角色特例；按 `ART_PIPELINE.md` 与 `MELEE_3D_INTEGRATION.md` 即可。远程再读 `RANGED_3D_INTEGRATION.md`。
