# 动画配置参考

共用行为见 [动画系统](../ANIMATION_STATE_SYSTEM.md)。配置读取在 UnitModel3D，合法字段与资源由 CardValidator 和内容契约共同验证。

## 映射与分段

| 配置 | 语义 |
| --- | --- |
| `deploy / idle / move / attack / death` | 基础状态与动作映射，使用区分大小写的真实片段名 |
| `idle_cycle / move_cycle / move_enter` | 固定轮播与进入移动片段；轮播可重复名称 |
| `initial_move` | 部署后尚未攻击或变形时的循环移动；读取已有攻击及形态序号（含客户端快照），任一发生后不再使用 |
| `attack_structure` | 攻击建筑时的专用动作 |
| `attack_hit / attack_recover` | 按普攻段对应命中与恢复片段 |
| `attack_move / attack_to_move` | 拳间移动或按段转跑；空字符串表示无专用片段 |
| `empowered_* / haste_move` | 强化待击的移动/攻击/收势/转跑，或主动加速移动 |
| `attack_enter / attack_retarget_enter / attack_loop` | 持续攻击起手、换目标和循环 |
| `visual_actions` | 技能与变形动作；映射名需与技能所选动作一致 |

动作支持 `animation`、`durations` 数组；`clip_ranges` 指定各段原片起止秒数，长度须对应。`visual_action_durations` 可按动作名提供时长。连续素材确认无缝后才将 `sequence_blend` 设为零。

`attack_clip_ranges / attack_hit_clip_ranges` 与攻击段逐项对应；空数组用整段。`death_clip_end` 是死亡源片裁剪终点，须为正数且不超过原长，再由 `death_duration` 缩放。

## 混合与路线

| 策略 | 默认秒数 | 用途 |
| --- | --- | --- |
| `action_in` | 0.08 | 进入新攻击、技能或变形 |
| `action_out` | 0.14 | 没有过渡素材时回基础状态 |
| `sequence` | 0.04 | 动作内部切片、过渡片段首尾 |
| `locomotion` | 0.10 | 待机/移动及移动样式互切 |
| `death` | 0.10 | 进入死亡 |
| `model_swap` | 0.02 | 换模型后的首片段 |
| `attack` | 0.06 | 显式攻击类混合；普通攻击入口仍用 action_in |

`transition_blends` 可覆盖策略。`clip_blends` 精确的“源片段>目标片段”优先，其次通配目标，之后才回退动作/路线覆盖和全局策略；零值合法，不能把某卡值改为全局默认。

`transitions` 先匹配实际来源片段到 move/idle，再匹配行为路线。转场描述可提供 `blend_in / blend_out` 和非负 `start_time`，起点必须小于原片长。

进入移动的来源优先级：专用 ToRun → 按段转跑 → 通用 move_enter。一条路线只选一种。使用过渡素材时首尾采用 sequence；完全没有时用 action_out。通用入跑用于部署/待机/攻击进入移动；技能与变形应选自身路线或直接混合。

## 时间与进度

- `cast_duration / impact_delay` 是权威总窗口与效果执行延迟；全身动作要求 `cast_locks` 包含 attack。锁可组合 movement、attack、facing，默认全锁。
- 技能 gameplay 字段 `independent_on_creation` 仅用于正 `impact_delay`、非持续区域的 `forward_area`；由 ActiveSkillEffectSystem 在预警创建时保存独立结果，由 CommandSchedule 结算，CardValidator 校验。它不是动画字段，不能由模型出现或动画名称推断释放。对应创建声在 audio.events 的 `start` 事件声明 `owner: "result"`，由权威创建事件派发并去重；不得再配置 `action_time`，也不由单位动作启动或取消。
- 普攻 Start 对齐 first_hit。配置 `attack_reference_interval` 后，Hit/Recover 按实际基础间隔与参考间隔之比缩放；不要同时设置手工 Hit/Recover 时长。未配置时沿用 attack_hit_duration / attack_recover_delay。
- 中途攻速变化同步剩余阶段与基础速率进度，不重置动作序号；恢复或晚到定位包含源片裁剪起点。技能、移动、部署和死亡不受普攻倍率影响。
- 持续攻击首次起手用 action_in，后续换目标/序列/循环用 sequence。退出时立即停止持续效果，收势不延长伤害。
- 新攻击序号允许跳号；重复序号不重播，同名新实例即使进度为零也需定位起点。

## 控制、模型与挂点

冰冻先定格当前姿势再取消旧动作，解除后混到合法新动作，不续播；眩晕取消普攻后短混合 Idle，已开始的普通技能、部署和变形继续。已有减速在免疫期间继续倒计时但被抑制，免疫结束后按剩余时间恢复；不按来源乘算。

动画库按实例深复制。材质叠加由统一表现层合成，保留原覆盖层及受击/冰冻后续 pass。头顶优先包装提供的锚点，再用 HeadAnchor，最后在接入或换模型时缓存投影回退；发射点可由包装提供方法或 BeamOrigin，不假设通用骨骼名。

`death_followup_scene_path / animation / duration` 配置后续模型；`death_followup_immediate` 为真时跳过原模型死亡，立即换后续模型。它只改变无碰撞死亡代理，成功复生不走死亡。

`visual_active_buff_scene` 须继承 ActiveBuffVisual3D，提供 configure/advance 接口；只读增益状态，结束恢复材质，换形重建。强化弹体外观在发射时固化，不改变伤害和碰撞。

具体裁剪与片段选择以 [单位动画页](../units/README.md) 为准，勿重复维护一份逐卡配置表。

`empowered_idle` 与 `empowered_move` 使用只读的下一击强化/循环被动就绪状态选择待机和移动片段。字段只影响表现；实际出手后切回基础姿态，取消前摇不消耗就绪状态。

## 原生命中节点映射

新卡必须在接入时核对原生动作的命中/出手节点，不能只凭观感填固定前摇。优先读取对应英雄bin的SpellDataResource（castFrame、mCastTime、mAnimationName）及动画绑定；核实帧率和实际导入片段长度，记录来源路径与数值。castFrame并不自动等于最终命中帧：多段、延迟和弹体技能还须区分施法、离弦、到达事件，找不到依据时明确记录待核实，不猜测为完成。

整段等比缩放时：**映射前摇 = 原始节点秒数 ÷ 原片长度 × 本游戏基础动作窗口**。原始节点秒数 = castFrame ÷ 已核实帧率；动作窗口通常为基础攻击间隔。运行时前摇与动作窗口同时除以攻速倍率，原片播放速率为原片长度÷窗口×攻速倍率。裁剪素材先扣除裁剪起点，再除以裁剪片长；分段动作使用各自窗口，不混用整段公式。

普通攻击的多种动作统一采用一个近似前摇，逐动作列出映射结果后选择合理公共值，记录误差；不因为动作不同引入不同普攻前摇，不为迁就节点更改攻击间隔。强化下一击可使用gameplay.empowered_first_hit，其余普攻沿用first_hit。强化普攻技能生效时刷新旧攻击周期，清除前摇、后摇和攻击冷却，从完整强化前摇重新起手。普通攻击与强化动作互切使用action_in混合，刷新取消事件不先播放Idle；强化结束转移动仍优先使用对应收势/转跑。已提交伤害和已创建弹体保留，未释放追加刀取消。

伤害/离弦仍由固定20Hz权威模拟在跨过节点的第一个Tick结算，动画与命中音效只消费结果。验收须覆盖多种普攻、强化下一击、连续攻击、攻速变化、中途强化、取消/冻结及客户端进度；单位动画页记录来源、原片时长、节点、公式、公共近似值和Tick误差，不能把动画事件作为伤害驱动。

持续特效场景可用ActiveBuffVisual3D.status_source选择active_buff（默认）或blood_rage；后者只读取血怒剩余时长，不受其他增益触发。
