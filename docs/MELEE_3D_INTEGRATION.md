# 普通近战 3D 模型接入

本教程只适用于“CardDB 已能表达玩法、单模型或简单阵营模型、通用状态动画”的普通近战。纳尔这类双模型/加法动画角色读自己的目录 README。

## 1. 检查素材

- 将 GLB 与外部纹理放到 `assets/units/<card_id>/source/`。
- 在 Godot 中确认模型、材质、AnimationPlayer、骨骼和真实动画名。
- 至少找出 Idle、Run、Attack、Death；部署动作按 `UNIT_DEPLOYMENT.md` 选择。

## 2. 包装场景

创建 `assets/units/<card_id>/<card_id>_view.tscn`，实例化源 GLB，只负责统一缩放、脚底落在原点和素材初始朝向。不要在包装场景实现伤害、位移或碰撞。普通模型不复制 `UnitModel3D` 状态机。

## 3. CardDB

```gdscript
"visual_scene_path": "res://assets/units/<card_id>/<card_id>_view.tscn",
"visual_forward_yaw": 0.0,
"visual_animations": {
    "deploy": "Respawn",
    "idle": "Idle",
    "move": "Run",
    "attack": ["Attack1", "Attack2"],
    "death": "Death",
    "death_duration": 0.8,
},
```

攻击数组按权威攻击序号循环。`first_hit` 是权威命中点，按素材动作调校但仍只写 CardDB；动画本身不触发伤害。`interval` 是玩法数值，不为迁就素材随意改平衡。需要分段动作时使用现有 `attack_hit` / `attack_recover` 配置，确认通用播放器确实读取后再添加字段。

## 4. 验收

- 两队朝敌方、移动方向和锁定目标方向正确；客户端使用完整方向快照。
- 模型大小、脚底、血条顶部锚点和遮挡正确；不改权威半径来修画面。
- 部署期间不能行动但能被命中和碰撞；攻击掉血时刻与动作合理。
- Death 由可靠表现事件播放，战斗节点当帧退出。
- mechanics 全通过，并在实际渲染中检查双方阵营和所有状态。

常见修正顺序：不可见先查资源路径/scale；反向先调 `visual_forward_yaw`；脚底错调包装位置；动画错查真实名称；命中观感只调该卡 `first_hit`。不要为单个素材改通用战斗逻辑。
