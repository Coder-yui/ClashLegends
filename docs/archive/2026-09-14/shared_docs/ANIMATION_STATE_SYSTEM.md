> 2026-09-14 整理前快照，可能含已纠正的说明。当前入口见 [文档首页](../../../README.md)。

# 单位动画状态系统

单位动画采用轻量的 `locomotion + action` 两通道设计，不引入 AnimationTree：

- `locomotion` 表示 `deploy / idle / move`，分别使用状态码 `0 / 1 / 2`。
- `action` 覆盖层处理 `attack / skill / transform / deploy / death`。
- 权威 Unit 经复用的 UnitPresentationState 只读视图发布状态、攻击序号/已流逝进度和 action 序号/时间轴；`UnitModel3D` 消费这些数据，动画结束回调不得结算伤害、技能、位移或索敌。

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
        "blend_in": 0.08,
        "blend_out": 0.14,
    },
},
"active_skills": [{
    # kind 的权威效果字段略
    "cast_duration": 1.2,
    "impact_delay": 0.55,
    "visual_action": "active",
    "cast_locks": ["movement", "attack", "facing"],
}],
```

`animation` 和 `durations` 都支持数组；单段动作和多段动作都可在 `visual_actions` 的描述字典中声明。`visual_action_durations` 作为按动作名提供时长的配置入口参与读取。

动作数组还可用 `clip_ranges` 为每段声明素材的 `[开始秒, 结束秒]`，以截取无动作持姿区而不改源资源；数组长度必须与 `animation` 相同。默认多段内部使用 `sequence` 混合，只有素材已经逐帧无缝衔接时才在动作描述中设置 `sequence_blend = 0.0`。例如格温按层数从 `Spell1_0` 尾部持姿区让出时间给数个保持原速的 `Spell1_B`，再无混合直连 `Spell1_C_anm`，四档动作都保持 1.5 秒。

## 全局切换与默认混合

变形与有全身主动动作的技能使用同一套 Action 规则。所有 `AnimationPlayer.play()` 都经过统一 transition policy，从当前任意骨骼 Pose crossfade 到目标片段；动画只决定表现，不能改变权威攻击、技能、部署或移动时序。

| 配置键 | 默认时间 | 用途 |
| --- | ---: | --- |
| `action_in` | `0.08s` | Idle/Move/Attack 进入一次新的 Attack、Skill 或 Transform 动作；部署结束进入 Attack 也使用它 |
| `action_out` | `0.14s` | Attack、Skill 或 Transform 在没有任何转场素材时直接退出到最终基础状态 |
| `sequence` | `0.04s` | 作者制作的 transition 首尾、技能多段、攻击 Start/Hit/Recover、连续攻击片段、移动序列内部 |
| `locomotion` | `0.10s` | Idle/Move 基础状态切换，以及普通移动与加速/强化移动互切 |
| `death` | `0.10s` | 任意生前 Pose 进入死亡动作 |
| `model_swap` | `0.02s` | 形态或死亡后续模型接入后的首个片段 |

`attack` 配置键的默认值为 `0.06s`，用于显式指定攻击类混合；普通攻击入口使用 `action_in = 0.08s`。各角色仍可用 `transition_blends` 覆盖，但没有必要时应使用全局值。腕豪普通/强化 W 按原始动画表分别配置入口混合 0.10 / 0.04 秒。

腕豪按实际来源片段配置 W→Move / Idle 收尾，能接下一拳时直接进入攻击；细节见 `cards/sett.md`。

全局切换归纳为：

1. 任意状态 → Death：`death`。
2. Deploy → Move/Attack：部署完整结束后再切；进入 Attack 用 `action_in`，进入 Move 按下述 transition 规则。
3. Move → Attack：新攻击用 `action_in`。
4. Attack → Move：有转场时用 `sequence` 首尾；无转场时用 `action_out`。
5. Move → Skill/Transform：`action_in`。
6. Skill/Transform → Move：有专用 ToRun 时用 `sequence` 首尾；无专用片段时用 `action_out` 直接进入 Run。
7. Attack → Skill/Transform：目标动作使用 `action_in`。
8. Skill/Transform → Attack：源动作结束用 `action_out` 进入排队的攻击。
9. 普通 Move ↔ Haste/Empowered Move：`locomotion = 0.10s`，不重播 `RunIn`。
10. `model_swap`：`0.02s`。

攻击序列中的下一轮普攻、Start → Hit → Recover，连续攻击的 enter/retarget/loop，以及技能和移动多段内部，都属于同一动作/序列内部切片，统一使用 `sequence = 0.04s`。

## Transition clip

有专门素材时可配置 `transitions`：

```gdscript
"transitions": {"attack>move": "Attack_To_Run"}
```

若两段素材本身已经逐帧对齐，可在同一个 route 描述中只关闭某一条边的 crossfade：

```gdscript
"transitions": {
    "skill>move": {
        "animation": "Skill_To_Run",
        "blend_in": 0.0,  # Skill → Skill_To_Run 直接切换
        "blend_out": 0.04 # Skill_To_Run → Run；省略时也回退到全局 sequence
    },
}
```

`blend_in` 表示前一 Action → transition clip，`blend_out` 表示 transition clip → 最终 Move；两者都允许为 `0.0`。未配置的边仍使用全局 `sequence`，因此无需为了一个精准接缝把角色的技能多段、普攻分段等全部设成零混合。

Move route 中的 transition 分为两类：

- 通用 `RunIn / IntoRun`：通过 `move_enter` 配置，只用于 `Deploy / Idle / Attack → Move`。默认播放链为 `前一动画 ─0.04→ RunIn/IntoRun ─0.04→ Run`。
- 技能或特殊动作专用 `ToRun`：通过 `transitions["...>move"]`、按段 `attack_to_move` 或 `empowered_attack_to_move` 配置。默认播放链为 `Skill/特殊动作 ─0.04→ 专用 ToRun ─0.04→ Run`；route 描述可以按上述方式覆盖单条边。

一条 Move route 只使用一种 transition 来源，优先级为专用 `ToRun`、按段 `attack_to_move`、通用 `move_enter`。使用专用 `ToRun` 或按段转场时直接进入最终 Run；没有这些片段时，Deploy、Idle 或 Attack 使用通用 `RunIn/IntoRun`。

`action_out` 与 `sequence` 的语义严格区分：

**有专用 transition clip 时使用 `sequence` blend；无专用 transition 时使用 `action_out` generic crossfade。** 通用 `move_enter` 本身也属于 transition clip。

- 有专用 transition clip 时，作者素材承担主要姿势转换，统一使用 `Action → sequence blend → Transition Clip → sequence blend → Move`；route 描述中的 `blend_in`、`blend_out` 可以分别覆盖两条边。
- 有通用 `move_enter` 时，它同样是作者制作的 transition，因此首尾都使用 `sequence`。
- 完全没有专用 `ToRun` 或通用 `move_enter` 时，crossfade 本身承担完整姿势转换，使用 `Action → action_out generic crossfade → Move`。普通 locomotion 状态之间仍使用 `locomotion`。

这条规则统一覆盖 `transitions["attack/skill/deploy/transform>move"]`、按段 `attack_to_move`、`empowered_attack_to_move` 和 continuous attack 的转跑路线。龙王的 Deploy/Idle 使用通用 `RunIn`，吐息 Attack → Move 使用更具体的 `Spell1_2Run` 并直接接 `Run1B`。不要新增角色名判断或 `Spell2 → Run` 等硬编码。

强化普攻仍属于 Attack 通道，可用 `empowered_move / empowered_attack / empowered_attack_hit / empowered_attack_recover / empowered_attack_to_move` 作为待命移动、出手、长后摇和转跑素材。普通多段攻击需要按本次动作选择不同转跑路线时，使用与 `attack` 等长的 `attack_move` 和 `attack_to_move` 数组；空字符串表示该段没有专用转场。所有这些片段都允许被下一次权威攻击或移动状态从任意进度打断。

主动加速移动可配置 `haste_move`；表现层读取权威/快照中的 buff 倍率，在 buff 开关当帧以 `locomotion = 0.10s` 切换移动动作。攻击动作的播放速度实时跟随权威攻速倍率，已经播放到中途的动作也会同步加速或恢复，但命中仍由 Unit 的固定计时决定。

持续攻击的首次 `attack_enter` 使用 `action_in`；`attack_retarget_enter`、enter 数组内部和进入 `attack_loop` 使用 `sequence`。数组按顺序播完后才进入循环，例如龙王换目标为 `new_looptoin ─0.04→ newtst ─0.04→ loop`。

## 联机

快照使用紧凑、固定长度的 Array；当前 `SNAPSHOT_PROTOCOL_VERSION = 13`，顶层为 `[version, server_tick, units, projectiles, towers, client_elixir, match_timer, overtime]`。Unit 固定载荷长度为 38，包含普通攻击基础速率时间轴、有效移动/攻击速率、动作权限，以及 action 时间轴、locomotion、强化攻击、技能资源启用状态、主动移速/攻速倍率、主动技能剩余次数与冷却、护盾比例；Projectile 载荷额外同步纯表现尺寸倍率。版本或载荷长度不匹配时整份快照直接丢弃；任何字段变更都必须提升版本并同步读写两端。晚到客户端按权威剩余时间 seek，动画时间轴只用于表现同步，不参与权威判定。

## 控制覆盖、速率与资源所有权

Unit 的 ControlState 保存冰冻、眩晕、移动减速和减攻速；AttackTimeline 保存普攻冷却、前摇、后摇及基础攻速下的表现已流逝时间。状态入口仍是 Unit.freeze/stun/apply_slow/apply_attack_speed_slow。相同和不同来源均保留已有“最长持续时间 + 最强倍率”聚合语义，不相乘；主动 Buff 也保持最长窗口/最高倍率/免疫 OR。免疫拒绝新减速，已有减速继续倒计时但被抑制，免疫到期重新生效。所有有效攻速变化通过旧/新倍率转换剩余阶段，重复刷新不会再拉伸计时。

消费者使用 `unit.presentation_state()`（每单位一个对象），包含基础行为、动作实例、控制标签、速率、进度与权限；本地/客户端路由在 Unit 查询入口完成。客户端重复动作序号不重播，晚到攻击按已流逝进度 seek。动画不能回调命中，音频不随 attack_rate 全局变速。

- 冰冻优先保持当前姿态，暂停动作表现；解除后按权威阶段恢复。
- 眩晕通过 `visual_animations.stun_enter/stun_loop/stun_exit` 可选配置。没有片段时保持姿态；有片段时眩晕动画自身以正常速率播放，冰冻重叠仍会暂停它。施法继续沿用控制期间暂停语义。
- 移动减速只作用基础移动；攻击速率只作用攻击表现；死亡始终解除控制覆盖并正常播放。
- 材质叠加由 UnitModel3D 唯一合成，受击与冰冻保留原 overlay 后续 pass。同类模型的 AnimationLibrary 在实例内深复制，不共享 loop_mode 修改。

包装根为 Node3D，包含可找到的 AnimationPlayer、明确朝向和脚底。头顶优先 `get_health_bar_anchor_local()`，其次 `HeadAnchor`，没有时只在接入/换模型时计算投影回退并缓存。发射点可用 `get_beam_origin_world()` 或 `BeamOrigin`；具体骨骼名属于该素材包装，龙王 Jaw 映射已移至其包装脚本。不能假设所有卡都有 Stun、某骨骼或发射点。

## 原始片段规则与攻速适配

`clip_blends` 配置 `"源片段>目标片段": 秒数`，精确边优先，其次 `"*>目标片段"`，最后回退到动作描述/路由覆盖与全局策略。零混合是合法值；只为已核验的素材配置，不把某张卡的值变成全局默认。所有普通播放与技能 section 入口均读取此表。

`transitions` 优先读取 `"实际来源片段>move"` / `"实际来源片段>idle"`，再回退到已有 `"attack/skill/...>move"` 等行为路由。Idle 收势在纯表现层播完回基础待机，任何新攻击、移动或更高优先级动作都能打断。转场描述可含非负 `start_time`，素材契约必须验证它小于动画长度；进入该转场时从此时间 seek，不改变权威移动/施法窗口。普通 W 已完整起身时跳过 ToRun 的低姿态开头，是项目适配而非宣称 LoL 原始配置含该裁剪。

持续攻击的 Idle 出口也走同一转场路由；例如龙王 `newtst/loop→Spell1_2Idle→Idle1_Base`。停止持续攻击时立即关闭光柱，纯表现收势不延后伤害停止。来源通过 `assigned_animation` 保留，单次片段自然结束后仍可选择专用收势；完成后不因来源记录而重复播放。全卡原表依据与尚未移植的选择条件见 [全卡对照](../../2026-09-13/research/all_cards_animation_comparison.md)。

分段普攻可配置 `attack_reference_interval`：参考间隔下 Hit 和 Recover 按素材原速播放，基础间隔改变后按 `实际基础间隔 / 参考间隔` 缩放片段时长；有收势时在完整 Hit 结束后接入，下一次权威攻击可提前打断。未配置该字段的卡继续使用既有 `attack_hit_duration / attack_recover_delay` 规则；Start 仍由权威 `first_hit` 窗口校准。该参考模式不应再同时配置手工 Hit/Recover 时长。

普攻 Buff/减攻速同时作用新一轮前摇起点、表现触发窗口、前摇/后摇/冷却剩余时间和播放速度。中途变速不重置序号或进度；晚到/恢复时按基础速率进度直接定位 Start、Hit 或 Recover，并保留跨段余量。技能、移动、部署、死亡使用各自时钟，不受普攻倍率影响。连招被取消时，递增表现序号允许跳号，使其选片余数继续匹配尚未命中的权威拳段；接收端按序号变化去重，不应假设每次一定 +1。

腕豪 W 使用同一源片段的两个连续 `clip_ranges`：0–0.8 秒原速播放，0.8 秒到片尾适配为 0.6 秒。普通和强化共享 0.8 秒权威命中与 1.4 秒施法窗口；不将整段按比例缩放而改变出拳时刻。同片段连续分段使用 `sequence_blend = 0`，客户端晚到仍按分段时间映射 seek。两套被动 Start→Hit 最终恢复原表 0.04 / 0 秒。

`death_clip_end` 可指定死亡动画源时间的裁剪终点，必须为有限正数且不超过源长度；`death_duration` 缩放这一裁剪段，结束仍使用 AnimationPlayer 的 section 完成事件。腕豪为 0–1.7 秒压到 0.8 秒，其他卡未配置时仍播放整段。

## 首击与再次接敌（2026-09-12 修正）

首次攻击没有上一击留下的冷却，进入射程立即开始 `first_hit / 攻速倍率` 的正常前摇。部署结束同 Tick 即可索敌并开始前摇或行军；不需要预装攻击间隔。已移除 `_attack_load`、移动装填和此前的部署预装补偿。

真实出手后 `cooldown` 记录到下一次允许出手的剩余时间；默认后摇为 `cooldown - 下一次前摇`。完整后摇结束后重新接敌即可开始正常前摇。若配置允许取消后摇并移动，再次接敌仅受真实剩余冷却约束：首次进入 Attack 的等待窗口为 `max(first_hit / 攻速倍率, cooldown)`，前摇与剩余冷却重叠，不能重算一个完整攻击周期。未出手就取消前摇不会创建冷却，重试时重新播放正常前摇。

本修正保留逐卡后摇移动策略、攻击连招间隔、攻速缩放及技能/变形已有重置规则；不新增动画驱动结算或网络字段。0.5/1/2 倍攻速回归覆盖首击、取消前摇重试、完整后摇后的短追击和提前取消后摇的快速重入；腕豪的多倍率连招回归保持通过。

连续同名攻击的新实例即使权威进度为零也 seek 起点；保持攻击晚到和控制恢复的进度对齐，避免同名 play 延续上次末尾。

`death_followup_immediate=true` 配合现有 death_followup_scene_path / animation / duration，在死亡入口立即替换表现模型并播放配置动作，跳过原模型 Death。仅改变无碰撞死亡代理；默认 false 保持纳尔等原有先后两段。凤凰蛋被击破使用此配置，成功复生不进入死亡表现。

### 按源时间段播放普攻

`attack_clip_ranges` / `attack_hit_clip_ranges` 与 attack / attack_hit 数组逐项对应；空数组使用完整片段，[start, end] 指定源秒数。播放器根据权威阶段时长缩放，快照对齐包含源起始偏移。赵信第三击使用同一源片段的 0–0.3 / 0.3–3.0 秒连续区段，阶段切换零混合。
