# 通用美术架构

本文只描述所有素材共用的架构与边界。具体近战流程见 `MELEE_3D_INTEGRATION.md`；远程差异见 `RANGED_3D_INTEGRATION.md`；部署选片见 `UNIT_DEPLOYMENT.md`；角色特例放角色目录 README。

完整新卡顺序为 2D 权威逻辑 → 3D 模型/动画 → 卡面 → 音频 → 联合验收，见 `AGENT_WORKFLOW.md`。本文的模型验收不代表整卡完成；音频专项流程见 `AUDIO_INTEGRATION.md`。

## 运行时分层

```text
CardDB 表现配置
  → BattlePresentation3D
  → UnitModel3D / TowerModel3D
  → assets 下的包装场景
```

`Unit`、`Tower` 和主机固定 Tick 是权威层。3D 代理只读取位置、状态、攻击序号、完整朝向、形态和可靠表现事件。客户端 Snapshot 已同步完整 `net_facing_direction`，不是只同步水平朝向，也不是未来 TODO。动画回调不得扣血、生成权威弹体、位移、改变碰撞或联网状态。

候选竞技场保存在 `assets/arena/rift_arena/rift_arena.tscn`，目前运行时仍使用 `assets/arena/arena_rift_v4.png`。候选场景的规格和 Blender 编辑流程见该目录 README；它只在独立预览中与单位/建筑共用正交相机。场景中不添加碰撞或导航，权威地面仍由 Main 格子常量定义。

## 资源与配置

```text
assets/cards/<card_id>_loading.jpg|png|webp
assets/units/<card_id>/source/<source files>
assets/units/<card_id>/<card_id>_view.tscn
assets/audio/units/<card_id>/<event_name_and_variant>.wav
```

同一卡两套阵营模型使用 `visual_scene_paths = [blue/order, red/chaos]`；单模型使用 `visual_scene_path`。CardDB 的 `visual_animations` 使用素材中真实、区分大小写的动画名。常用键为 `deploy`、`idle`、`idle_cycle`、`move`、`move_enter`、`move_cycle`、`attack`、`attack_hit`、`attack_recover`、`attack_structure`、`death`、`visual_actions`；`idle_cycle` 可按固定顺序循环待机片段并允许重复名称，只影响表现。详细合法结构由 `CardDB.validate_all()` 检查，实际播放行为以 `unit_model_3d.gd` 为准。

`visual_forward_yaw`、包装场景 scale/脚底偏移、`visual_radius` 都是表现数据，不能反向修改 `radius`。CardArt 自动发现 `<card_id>_loading.*`，无需在代码登记图片路径。

空军包装场景仍按各自素材校准原始 scale；`UnitModel3D` 会读取包装内全部网格的实际底部，并把整个包装场景平移到 `CardDB.AIR_VISUAL_ELEVATION` 声明的统一离地高度。该规则只改变3D表现位置，不缩放模型，也不改变权威地面坐标和任何战斗判定。空军血条的头顶约束以同一离地平面计算，必须随模型一起上移。

卡面获取遵循固定优先级：英雄先从 CommunityDragon 下载基础皮肤 Loading Screen；没有原生图但有模型时拍 3D 模型；图像和模型都没有时再用 AI 生成。已有资源接入后不得被后续流程覆盖。

单位动画使用 `locomotion + action` 双通道、统一 Pose crossfade 和可选专用 transition clip。技能动作描述、施法权限与接入示例见 `ANIMATION_STATE_SYSTEM.md`。

## 通用接入顺序

1. 确认任务 Router 和 `card_id`。
2. 源文件归档到 `source/`，不要编辑 `.import`。
3. 检查模型层级、材质、骨骼、AnimationPlayer 和真实动画名。
4. 创建极简包装场景，校正 scale、脚底与初始朝向。
5. 只在 CardDB 配路径/动画映射；普通角色不新增表现脚本。
6. 运行 mechanics（含路径和字段 validator）。
7. F5 目视双方阵营、部署/待机/移动/攻击/死亡、脚底、遮挡和朝向。
8. 完整新卡继续核对卡面，并按 `AUDIO_INTEGRATION.md` 给当前使用的表现/命中事件接入声音；音频不挂在模型动画方法轨道中，不反向控制权威时序。

只有素材本身需要组合、网格过滤或双模型切换时才增加角色专属包装脚本，并把说明放在 `assets/units/<card_id>/README.md`。
