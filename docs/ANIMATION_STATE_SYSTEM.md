# 单位动画状态系统

单位动画采用轻量的 `locomotion + action` 两通道设计，不引入 AnimationTree：

- `locomotion` 只表示 `idle / move`；部署阶段保留兼容码 `0`。
- `action` 覆盖层处理 `attack / skill / transform / deploy / death`。
- 权威 Unit 只发布状态、攻击序号和 action 序号/时间轴；`UnitModel3D` 消费这些数据，动画结束回调不得结算伤害、技能、位移或索敌。

动作优先级为 `death > deploy > transform > skill > attack > locomotion`。高优先级动作期间到达的普攻序号会排队，动作结束当帧根据最新权威状态恢复到 Attack、Move 或 Idle。Move/Run_In 和普通攻击都允许在素材任意进度被更高层动作打断。

## 施法权限

带 `cast_duration` 的技能默认锁定移动、普通攻击和朝向。`active_skill.cast_locks` 可从下列值中组合；若配置了全身 `visual_action`，必须包含 `attack`：

```gdscript
"cast_locks": ["movement", "attack", "facing"] # 站定施法（默认）
"cast_locks": ["attack", "facing"]             # 可移动，不能普攻
"cast_locks": []                                # 纯 Buff，不影响基础行为；不能同时配置全身 visual_action
```

Gameplay lock 与动画优先级互不推导：一个全身 Skill 动画可以伴随权威位移，但不能让权威普攻继续发生。没有动作素材的 Buff 可以只开 gameplay 窗口。技能效果/impact 仍由对应 kind 的固定模拟代码结算。

## 统一主动技能时间线

主动技能统一遵循：

```text
Player Input
    ↓
Authoritative Command Buffer（10 ticks / 0.5s）
    ↓
Cast Start
    ↓ impact_delay
Gameplay Impact
    ↓ cast_duration
Cast End
    ↓
Locomotion / Attack
```

Command Buffer 用于吸收联网输入延迟；`cast_duration` 是技能自身的施法窗口；`impact_delay` 是从 Cast Start 到效果生效的时刻。三者是不同概念，动画只读取权威时间线，不能触发 Gameplay Impact。施法者被冻结或眩晕时，施法与 impact 倒计时和动作表现同时暂停；施法者在 impact 前死亡则取消尚未发生的效果。

## CardDB 动作配置

普通英雄只需配置 `idle / move / attack / death`。有完整技能动作时，在 `visual_actions` 增加描述，并在技能上配置 `visual_action / cast_duration / cast_locks`：

```gdscript
"visual_actions": {
    "active": {
        "animation": "Spell2",
        "kind": "skill",
        "durations": [1.2],
        "blend_in": 0.06,
        "blend_out": 0.12,
    },
},
"active_skill": {
    # kind 的权威效果字段略
    "cast_duration": 1.2,
    "impact_delay": 0.55,
    "visual_action": "active",
    "cast_locks": ["movement", "attack", "facing"],
},
```

`animation` 和 `durations` 都支持数组。旧的动画名/动画名数组写法以及 `visual_action_durations` 仍兼容，但新技能优先使用同一描述字典，避免生命周期配置散落。

## 转场

所有 `AnimationPlayer.play()` 都经过统一 transition policy，从当前任意骨骼 Pose crossfade 到目标片段。默认类别为 `locomotion / action_in / action_out / attack / sequence / death / model_swap`，可用 `transition_blends` 按角色覆盖。

有专门素材时配置 `transitions`，优先于通用 crossfade：

```gdscript
"transitions": {"attack>move": "Attack_To_Run"}
```

龙王的 `Spell1_2Run` 使用这条通用映射；不要新增角色名判断或 `Spell2 -> Run` 等硬编码。没有专门片段时，Skill/Transform/Attack 会直接从当前 Pose 按统一 blend-out 进入目标动作。

## 联机

快照使用紧凑 Array，并保留原有 Unit 字段下标；当前协议在顶层携带 `SNAPSHOT_PROTOCOL_VERSION`、权威 `server_tick`，Unit 载荷尾部继续追加 action 总时长、剩余时长和 locomotion。晚到客户端按权威剩余时间 seek，不从技能第一帧补播；旧的无版本载荷仍可降级为原组合状态。动画时间轴只用于表现同步，不参与权威判定。
