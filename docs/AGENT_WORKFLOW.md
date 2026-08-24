# Agent 继续开发工作流

本文是给后续 Agent 的项目操作手册。目标是让一个没有参与过历史提交的 Agent，也能从需求判断改动范围，完成一张新卡或一套新素材，并把结果验证到可运行、可交接的状态。

## 0. 开始前：读取上下文并确认边界

在修改文件前按顺序检查：

```bash
git status --short --branch
sed -n '1,260p' docs/DEV_PLAN.md
sed -n '1,320p' docs/CARD_DESIGN.md
sed -n '1,260p' docs/ART_PIPELINE.md
```

然后确认：

- 当前仍处于阶段 3（主机权威联机）和阶段 4（美术接入）进行中；
- 工作区已有的未提交修改属于用户，不能覆盖或回退；
- 需求是普通单位、建筑、法术、特殊机制、卡面、3D 模型，还是它们的组合；
- 新卡的稳定 `card_id`、中文显示名、费用、阵营表现、是否进入玩家卡池已经明确。

如果需求只是“增加一张普通地面近战单位”，通常只需要 `CardDB` 数据、可选的卡面和 3D 包装场景，不要先改通用战斗脚本。如果需求包含隐身、穿透、召唤、死亡效果、位移、眩晕、减速或新的法术效果，则必须把它当作“代码 + 数据 + 回归”的完整机制任务。

## 1. 先选实现路径

| 需求形态 | 最小实现路径 | 需要额外确认 |
| --- | --- | --- |
| 普通地面近战 | `CardDB.all()` 新增 unit 条目，复用 `_spawn_unit()` | `size_tier`、`radius`、`first_hit`、目标规则 |
| 普通远程 | 普通单位字段 + `projectile_speed` 和表现字段 | 读 [`RANGED_3D_INTEGRATION.md`](RANGED_3D_INTEGRATION.md)，伤害必须在弹体到达时结算 |
| 空中/持续攻击 | unit 条目 + 已有 `is_air` / `is_continuous_attack` 字段 | 空地目标规则、范围伤害和表现层配置 |
| 建筑 | `type = "building"`、`is_building = true`，复用建筑占地注册 | 只有墓碑已有召唤逻辑；新的生命周期/召唤行为需改 `Unit` 权威逻辑 |
| 现有冰冻以外的法术 | 数据条目 + `main.gd::_cast_spell()` 的 `match` 分支 | 目标过滤、范围相交、主机 RPC/客户端特效、回归用例 |
| 新状态或特殊攻击 | 先写玩法规则，再扩展 `Unit`/`main.gd` 的权威数据流 | 不能只在 3D 动画或客户端实现 |

所有单位、塔和建筑都必须继续满足 `combatants` 统一接口：`team`、`hp`、`body_radius`、`take_damage(amount)`。新增逻辑必须能在主机固定 tick 下稳定运行。

## 2. 新增卡牌：从数据开始

### 2.1 设计和登记

1. 在 [`docs/CARD_DESIGN.md`](CARD_DESIGN.md) 的费用曲线、DPS、克制关系中做一次设计检查。
2. 选择稳定的英文小写 `snake_case` `card_id`。它会同时成为资源目录、卡面文件名、网络消息和测试查找键，后续不要轻易重命名。
3. 在 `scripts/data/card_db.gd` 的 `CardDB.all()` 中添加条目。数值、类型、体型和表现配置集中写在这里。
4. 默认 `selectable` 为 true；只有纯系统单位（例如不希望出现在卡组的召唤物）才显式写 `selectable = false`。
5. 普通单位不要在 `main.gd` 加角色名分支。`CardDB.selectable_ids()` 会让选卡界面和 AI 卡池自动发现它，`CardArt` 也会自动查找同名卡面。

普通地面近战的最小数据骨架：

```gdscript
"<card_id>": {
    "name": "中文名", "cost": 3, "type": "unit",
    "hp": 480.0, "damage": 52.0, "range": 28.0,
    "speed": SPEED_MEDIUM, "interval": 0.9, "first_hit": 0.28,
    "size_tier": SIZE_MEDIUM, "radius": RADIUS_MEDIUM,
    "visual_radius": RADIUS_MEDIUM + VISUAL_RADIUS_PADDING,
    "mass": 4.0, "sight": 200.0,
    "color": Color(0.35, 0.70, 0.90),
    "is_air": false, "building_only": false, "can_attack_air": false,
},
```

不要照抄示例数值；示例只说明字段形状。`radius` 应使用七档常量，不要为某个模型随意写一个独立碰撞半径。

### 2.2 判断是否需要代码

- 只使用已有字段的普通单位、普通远程、空中单位和持续攻击单位，先尝试只改 `CardDB`。
- 新法术必须在 `_cast_spell()` 增加 `match` 分支；只在 `CardDB` 写 `radius` 或 `duration` 不会自动产生效果。
- 新建筑只有占地、血量、寿命等已有通用行为时才能直接复用；新召唤物、周期效果和死亡触发都要在主机权威逻辑中实现。
- 新的冲锋、连招、隐身、弹体拦截等机制要沿用 `_spawn_unit()` / `launch_attack()` / `_resolve_attack_hit()` 的数据流，并补测试覆盖命中、死亡、目标失效和网络路径。

### 2.3 卡牌数据自检

至少检查：

- `CardDB.all().has(card_id)` 且 `CardDB.all()[card_id].name`、`cost`、`type` 正确；
- `type` 只使用 `unit`、`building`、`spell`；
- 单位的 `hp`、`damage`、`range`、`speed`、`interval`、`first_hit`、`size_tier`、`radius`、`mass`、`sight` 与定位一致；
- 远程单位的 `projectile_speed > 0`，并设置正确的 `first_hit`（离弦时刻），而不是把它当成命中时刻；
- 空中单位设置 `is_air`，能对空的单位设置 `can_attack_air`；攻城单位才使用 `building_only`；
- 新字段有对应读取代码。没有读取方的字段只是注释，不是功能。

## 3. 接入卡面和 3D 美术

先完成卡牌数据，再接表现资源，这样可以先用占位色块跑通战斗。资源流程如下：

1. 卡面放到 `assets/cards/<card_id>_loading.jpg`、`.png` 或 `.webp`。文件名必须与 `card_id` 完全一致，UI 会自动按顺序查找这三种扩展名；没有卡面时会显示数据色占位，不会阻塞玩法测试。
2. 原始 GLB 和纹理放到 `assets/units/<card_id>/source/`，统一使用英文 `snake_case`。不要手工编辑 Godot 生成的 `.import` 文件。
3. 让 Godot 完成导入，在编辑器里实际检查材质、骨骼、AnimationPlayer、脚底位置、朝向和动画是否存在；动画名区分大小写，不要按文件名猜。
4. 创建 `assets/units/<card_id>/<card_id>_view.tscn` 作为运行时包装场景，包装场景只负责实例化 GLB、校正缩放、朝向和脚底原点。
5. 在 `CardDB` 中设置 `visual_scene_path` 或双方模型使用的 `visual_scene_paths`，并显式填写 `visual_animations` 的 `deploy`、`idle`、`move`、`attack`、`death`。
6. 普通近战执行 [`docs/MELEE_3D_INTEGRATION.md`](MELEE_3D_INTEGRATION.md)；远程单位额外执行 [`docs/RANGED_3D_INTEGRATION.md`](RANGED_3D_INTEGRATION.md)；部署动作按 [`docs/UNIT_DEPLOYMENT.md`](UNIT_DEPLOYMENT.md) 选择。
7. 模型尺寸在包装场景中调，战斗尺寸在 `CardDB.radius` 中定。模型、卡面、闪白、死亡代理都不能调用 `take_damage()` 或改变权威位置。

## 4. 回归顺序

### 4.1 代码和机制

先运行最便宜的检查，再做实机观察：

```bash
Godot --headless --path . --script tests/mechanics_check.gd
```

如果是新行为，不要只依赖旧测试通过。应在 `tests/mechanics_check.gd` 增加一个有明确名字的最小用例，至少覆盖：

- 生成入口和部署延迟；
- 目标筛选、移动/攻击或法术范围；
- 伤害在正确的权威时刻发生；
- 死亡、目标失效、建筑占地释放或状态结束；
- 远程弹体的发射、飞行、命中和销毁；
- 主机广播和客户端收到的表现事件（如果涉及联网）。

### 4.2 Godot 编辑器 / F5 目视

新单位至少用玩家队和敌方队各部署一次，检查：

- 卡面、费用、名称、选卡和随机卡组均能找到新卡；
- 部署约 0.5 秒后生成，单位的 `deploy_time` 期间不自主行动但能受击；
- 模型脚底贴地、尺寸与同档位单位一致、阵营方向正确；
- Idle、Move、Attack、Death 映射真实存在，攻击动作循环自然；
- 近战掉血贴近武器命中姿态；远程先离弦、后在弹体抵达时掉血；
- 模型死亡后不再阻挡、攻击或被索敌，视觉代理按 Death 时长清理；
- 塔、建筑、普通单位和客户端视角都没有异常遮挡、偏移或反向。

### 4.3 联机冒烟

在两个终端启动：

```bash
Godot --headless --path . -- --mode=host --auto-test
Godot --headless --path . -- --mode=join --ip=127.0.0.1 --auto-test
```

实际通过卡组或开发面板部署新卡，确认：客户端只发送部署请求；主机校验区域、占位和费用后统一延迟生效；主机广播单位、法术、弹体、受击/死亡事件；客户端只插值和播放，不自行结算伤害。新卡没有进入自动样本时，必须手动部署，不能以旧卡测试通过代替新卡验收。

## 5. 交付和提交

完成前执行：

```bash
git diff --check
git status --short
git diff --stat
git diff -- scripts/data/card_db.gd scripts/main.gd scripts/unit.gd tests/mechanics_check.gd
```

最终交付说明应包含：

- 新卡的 `card_id`、类型、费用和玩法/机制摘要；
- 修改过的脚本、测试和资源路径；
- 使用的动画名、缩放、脚底偏移、朝向和 `first_hit`（如接入 3D）；
- headless 机制回归、F5 目视和 host/join 联机结果；
- 尚未完成的卡面、动画、音效或特殊机制；
- 没有把用户原有未提交修改混入本次提交。

提交信息使用能描述结果的中文或英文，例如：

```bash
git add README.md docs/AGENT_WORKFLOW.md docs/CARD_DESIGN.md docs/ART_PIPELINE.md assets/README.md
git commit -m "feat: add <card_id> card workflow implementation"
```

是否 push 由当前任务授权决定；用户明确要求同步远端时，再确认当前分支和远端后执行 `git push origin <branch>`，并在交付时报告提交哈希和远端分支。

## 6. 常见失败判断

| 现象 | 先检查 |
| --- | --- |
| 新卡不出现在选卡 | `selectable`、`CardDB.all()` 语法、`CardDB.selectable_ids()` |
| 卡面不显示 | 文件名是否为 `<card_id>_loading.*`，扩展名是否为 jpg/png/webp |
| 模型不显示 | `visual_scene_path` 是否指向包装 `.tscn`，GLB/纹理是否导入成功 |
| 动画不播放 | AnimationPlayer 的实际大小写名称、映射字段是否为字符串或非空数组 |
| 远程一发就掉血 | 是否错误地把 `projectile_speed` 设为 0，或把伤害写进动画/表现脚本 |
| 单机正常、联机不同步 | 是否绕过 `_spawn_unit()` / `_cast_spell()`，是否只在客户端加了逻辑 |
| 新法术无效果 | 是否在 `_cast_spell()` 添加分支，是否有主机 RPC/视觉同步和回归用例 |
| 模型悬空/下沉 | 包装场景的 `scale` 与脚底 `position` 是否一起校正；不要改权威 `radius` 解决 |
