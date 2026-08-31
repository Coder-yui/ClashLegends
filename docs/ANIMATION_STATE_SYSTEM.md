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

部署是最高优先级的生前锁定窗口。部署计时结束前，单位不能自主移动、攻击或释放主动技能；玩家的主动技能按钮保持可见但禁用，部署完成的同一固定 Tick 才启用。Host 的 `_active_skill_is_legal()` 仍会再次校验 `is_deployed()`，按钮状态只提供反馈，不替代权威判定。

## 统一主动技能时间线

主动技能统一遵循：

```text
Player Input
    ↓ input_tick（客户端点击时观察到的 Host Tick）
Authoritative Command Buffer（input_tick + 10 ticks / 0.5s）
    ↓
Cast Start
    ↓ impact_delay
Gameplay Impact
    ↓ cast_duration
Cast End
    ↓
Locomotion / Attack
```

Command Buffer 从玩家输入时刻开始计时，用于吸收联网输入延迟；网络传输时间消耗这 10 Tick 的一部分，Host 不会在收到网络请求后重新追加完整 10 Tick。客户端只提交 `input_tick`，Host 计算 `execute_tick = input_tick + 10`；若目标已到达则按 late policy 拒绝，不重新排队。`cast_duration` 是技能自身的施法窗口；`impact_delay` 是从 Cast Start 到效果生效的时刻。三者是不同概念，动画只读取权威时间线，不能触发 Gameplay Impact。施法者被冻结或眩晕时，施法与 impact 倒计时和动作表现同时暂停；施法者在 impact 前死亡则取消尚未发生的效果。

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

## 全局切换与默认混合

变形与有全身主动动作的技能使用同一套 Action 规则。所有 `AnimationPlayer.play()` 都经过统一 transition policy，从当前任意骨骼 Pose crossfade 到目标片段；动画只决定表现，不能改变权威攻击、技能、部署或移动时序。

| 配置键 | 默认时间 | 用途 |
| --- | ---: | --- |
| `action_in` | `0.06s` | Idle/Move/Attack 进入一次新的 Attack、Skill 或 Transform 动作；部署结束进入 Attack 也使用它 |
| `action_out` | `0.12s` | Attack、Skill 或 Transform 在没有任何转场素材时直接退出到最终基础状态 |
| `sequence` | `0.02s` | 作者制作的 transition 首尾、技能多段、攻击 Start/Hit/Recover、连续攻击片段、移动序列内部 |
| `locomotion` | `0.08s` | Idle/Move 基础状态切换，以及普通移动与加速/强化移动互切 |
| `death` | `0.08s` | 任意生前 Pose 进入死亡动作 |
| `model_swap` | `0.02s` | 形态或死亡跟随模型替换后的首个片段 |

`attack` 作为兼容配置键保留，默认值与 `action_in` 同为 `0.06s`；通用播放路径不再依赖旧的 `0.05s attack` 特例。各角色仍可用 `transition_blends` 覆盖，但没有必要时应使用全局值。腕豪蓄意轰拳不再配置 `blend_in = 0.05 / blend_out = 0.08`，直接使用 `action_in = 0.06 / action_out = 0.12`。

全局切换归纳为：

1. 任意状态 → Death：`death`。
2. Deploy → Move/Attack：部署完整结束后再切；进入 Attack 用 `action_in`，进入 Move 按下述 transition 规则。
3. Move → Attack：新攻击用 `action_in`。
4. Attack → Move：有转场时用 `sequence` 首尾；无转场时用 `action_out`。
5. Move → Skill/Transform：`action_in`。
6. Skill/Transform → Move：有专用 ToRun 时用 `sequence` 首尾；无专用片段时用 `action_out` 直接进入 Run。
7. Attack → Skill/Transform：目标动作使用 `action_in`。
8. Skill/Transform → Attack：源动作结束用 `action_out` 进入排队的攻击。
9. 普通 Move ↔ Haste/Empowered Move：`locomotion = 0.08s`，不重播 `RunIn`。
10. `model_swap`：`0.02s`。

攻击序列中的下一轮普攻、Start → Hit → Recover，连续攻击的 enter/retarget/loop，以及技能和移动多段内部，都属于同一动作/序列内部切片，统一使用 `sequence = 0.02s`。

## Transition clip

有专门素材时可配置 `transitions`：

```gdscript
"transitions": {"attack>move": "Attack_To_Run"}
```

Move route 中的 transition 分为两类：

- 通用 `RunIn / IntoRun`：通过 `move_enter` 配置，只用于 `Deploy / Idle / Attack → Move`。播放链为 `前一动画 ─0.02→ RunIn/IntoRun ─0.02→ Run`。
- 技能或特殊动作专用 `ToRun`：通过 `transitions["...>move"]`、按段 `attack_to_move` 或 `empowered_attack_to_move` 配置。播放链为 `Skill/特殊动作 ─0.02→ 专用 ToRun ─0.02→ Run`。

两类 transition 在一条 Move route 中互斥。找到专用 `ToRun` 后会直接进入最终 Run，不再追加通用 `move_enter`；只有没有专用片段时，Deploy、Idle 或 Attack 才回退到通用 `RunIn/IntoRun`。

`action_out` 与 `sequence` 的语义严格区分：

**有专用 transition clip 时使用 `sequence` blend；无专用 transition 时使用 `action_out` generic crossfade。** 通用 `move_enter` 本身也属于 transition clip。

- 有专用 transition clip 时，作者素材承担主要姿势转换，统一使用 `Action → sequence blend → Transition Clip → sequence blend → Move`。上层即使传入 `action_out` 或 action 描述里的 `blend_out`，也不会把这段较长混合套在专用片段上。
- 有通用 `move_enter` 时，它同样是作者制作的 transition，因此首尾都使用 `sequence`。
- 完全没有专用 `ToRun` 或通用 `move_enter` 时，crossfade 本身承担完整姿势转换，使用 `Action → action_out generic crossfade → Move`。普通 locomotion 状态之间仍使用 `locomotion`。

这条规则统一覆盖 `transitions["attack/skill/deploy/transform>move"]`、按段 `attack_to_move`、`empowered_attack_to_move` 和 continuous attack 的转跑路线。龙王不再使用 `move_enter_from_deploy_only / move_enter_after_attack` 旧覆盖：Deploy/Idle 可使用通用 `RunIn`，吐息 Attack → Move 则由更具体的 `Spell1_2Run` 优先并直接接 `Run1B`。不要新增角色名判断或 `Spell2 → Run` 等硬编码。

强化普攻仍属于 Attack 通道，可用 `empowered_move / empowered_attack / empowered_attack_hit / empowered_attack_recover / empowered_attack_to_move` 替换待命移动、出手、长后摇和转跑素材。普通多段攻击需要按本次动作选择不同转跑路线时，使用与 `attack` 等长的 `attack_move` 和 `attack_to_move` 数组；空字符串表示该段没有专用转场。所有这些片段都允许被下一次权威攻击或移动状态从任意进度打断。

主动加速移动可配置 `haste_move`；表现层读取权威/快照中的 buff 倍率，在 buff 开关当帧以 `locomotion = 0.08s` 切换移动动作。攻击动作的播放速度实时跟随权威攻速倍率，已经播放到中途的动作也会同步加速或恢复，但命中仍由 Unit 的固定计时决定。

持续攻击的首次 `attack_enter` 使用 `action_in`；`attack_retarget_enter`、enter 数组内部和进入 `attack_loop` 使用 `sequence`。数组按顺序播完后才进入循环，例如龙王换目标为 `new_looptoin ─0.02→ newtst ─0.02→ loop`。

## 联机

快照使用紧凑 Array，并保留原有 Unit 字段下标；当前协议在顶层携带 `SNAPSHOT_PROTOCOL_VERSION`、权威 `server_tick`，Unit 载荷尾部继续追加 action 时间轴、locomotion、强化攻击、技能资源启用状态及主动移速/攻速倍率。晚到客户端按权威剩余时间 seek，不从技能第一帧补播；旧的无版本载荷仍可降级为原组合状态。动画时间轴只用于表现同步，不参与权威判定。
