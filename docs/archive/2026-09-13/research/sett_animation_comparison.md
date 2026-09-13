# 腕豪原始动画图与当前实现对照

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

本页保留修改前的审查基线；后续已实施修正，当前行为与验证见 [腕豪卡牌文档](../../../units/sett.md)。

日期：2026-09-12。范围：基础皮肤、当前已使用的普攻、W、待机与移动；其余技能只用于理解图结构。本次是数据与代码审查，没有修改 gameplay、动画配置、模型或音频，没有宣称完成视觉或试听验收。

## 结论

现有普攻的主要片段选择和分段顺序有原始数据支持，不需要推倒重做。值得进一步验证的是分段的播放速度、按实际片段区分的混合，以及 W 的收尾路线。LoL 的完整操作与动作选择系统不适合直接搬入本项目：我们只需要覆盖自动攻击、追击、主动技能、控制与死亡实际会请求的动作。

优先级建议：先观察被动拳 Hit 的整段加速是否压缩了重要动作，再验证普通/强化 W 到移动的专用转场，最后微调逐边混合。80% 参数、左右转身、跑步变体等应分别决策，不随素材自动改变当前玩法。

## 证据与还原方法

- 原始图：`/Users/czh/Tools/lol-asset-tools/card_audio_batch/sett/data/characters/sett/animations/skin0.ritobin`。下文的“原图 L…”均指这个文件。
- 原始包：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/Sett.wad.client`。用现有 `wadtools list --hash … -F json` 只读核对动画资源哈希对应的真实路径。
- 项目定义：[sett.gd](../../../../scripts/data/cards/sett.gd)；播放实现：[unit_model_3d.gd](../../../../scripts/presentation/unit_model_3d.gd)；玩法时序：[unit.gd](../../../../scripts/unit.gd)。
- [证据摘录 JSON](sett_animation_evidence.json) 保存原图节点、选定混合条目的原始键/字段/行号、GLB 动画时长和源文件 SHA-256。结论只针对这份本地素材版本，不宣称代表所有 LoL 版本。

原图有 90 个动画节点、3534 个混合表项。将每个 u64 键拆为高/低 32 位后，3534 项的两半都能匹配图内节点；字符串节点名使用转小写后的 FNV-1a 32 位哈希核对。部分原本无名的节点可用候选名反算匹配，例如 `Attack2_Passive_Hit = 0xc39c9139`、`Spell2_Into_Run_Base = 0x6c5af74e`。这些是哈希匹配的名称解释，原始 token 仍保留在 JSON 中。

下文按“高 32 位为源、低 32 位为目标”解释混合表，与 W→跑步、Hit→收势等命名和结构一致；未取得 Riot 引擎查表代码，因此方向和运行时细节属于有强数据支持的解释，不能当成完整源码还原。`mTime` 原始数值按时间混合理解；缺少引擎对速度倍率、嵌套节点和默认值的完整处理语义。

**混合表不是玩法状态转换许可表。** 它描述请求切换时如何衔接，不证明这些切换在实战中都能发生。表内甚至存在 Death→舞蹈节点的转场配置，不能据此认为死亡期间可以跳舞。没有某条显式表项也不等于不能切换、必然硬切或不使用默认混合。

## 1. 普攻：分段基本正确，四拳选择顺序仍是项目规则

| 本项目第几拳 | 原图序列 | 当前素材 | 判断 |
| --- | --- | --- | --- |
| 1 | `Attack1_Start → Attack1_Hit`（L926） | 同名两段 | 组成与顺序一致 |
| 2 | `Attack1_Passive_Start → Attack1_Passive_Hit → Attack1_Passive_Into_Idle`（L894） | 中段名为 `Sett_Attack1_Passive_anm` | 组成与顺序一致，命名差异已有资源路径证据 |
| 3 | `Attack2_Start → Attack2_Hit`（L942） | 同名两段 | 组成与顺序一致 |
| 4 | `Attack2_Passive_Start → 0xc39c9139 → Attack2_Passive_Into_Idle`（L910） | 中段名为 `Sett_Attack2_Passive_anm` | 组成与顺序一致；无名节点哈希匹配 `Attack2_Passive_Hit` |

原始节点 `Attack1_Passive_Hit` 的资源哈希 `b0eba0a24c327b3c` 对应 `sett_attack1_passive.anm`；第二套中段 `bc28533968ab3aa0` 对应 `sett_attack2_passive.anm`。Godot 资源名中的 `.anm` 被转为 `_anm`，不能因命名不同判定选错素材。

但这些序列并未在此图中构成一个“永远按 1→2→3→4 循环”的总序列。当前 `(serial - 1) % attacks.size()` 的固定选择、`[0.28, 1.05, 0.28, 1.05]` 命中间隔、无目标自动追击都是本项目规则；仅凭此图无法证明 LoL 遇到换目标、攻击取消、脱战或技能插入时也保持同样顺序。

### 当前时间分配不是原始序列时长的直接保留

下表时长来自项目 GLB，另用 Godot 4.7.1 实际加载包装场景读取 AnimationPlayer 核对。它们是当前导入素材时长，不是 LoL 实战攻击窗口。播放速度为基础攻速下代码请求的 `素材时长 / 目标时长`，不计混合和被下一动作打断的影响。

| 片段 | 导入时长 | 当前目标时长 | 请求播放速度 |
| --- | ---: | ---: | ---: |
| `Attack1_Start` | 0.300 s | 0.120 s | 2.50× |
| `Attack1_Passive_Start` | 0.300 s | 0.120 s | 2.50× |
| `Attack2_Start` | 0.333 s | 0.120 s | 2.78× |
| `Attack2_Passive_Start` | 0.300 s | 0.120 s | 2.50× |
| `Attack1_Hit` | 2.367 s | 1.100 s | 2.15×，允许提前打断 |
| `Attack2_Hit` | 2.333 s | 1.100 s | 2.12×，允许提前打断 |
| `Sett_Attack1_Passive_anm` | 1.367 s | 0.320 s | 4.27× |
| `Sett_Attack2_Passive_anm` | 1.467 s | 0.320 s | 4.58× |
| 两段 `Passive_Into_Idle` | 各 1.333 s | 不指定 | 1.00×，允许提前打断 |

依据：`_play_attack()` 将 Start 缩放到 `first_hit_time`；`_update_attack_stages()` 将带 recover 的 Hit 缩放到 `attack_recover_delay`；`_play_attack_clip()` 对整个片段等比变速。普通 Hit 未配置时长覆盖，回退到 `_attack_duration = attack_interval = 1.1`，不是连招数组中的 0.28。

因此 `attack_recover_delay = 0.32` 不只是“等待 0.32 秒后收势”，还意味着“让整个被动 Hit 在 0.32 秒内播完”。如果长素材主要是持姿尾段，裁掉持姿、保留有效动作速度可能更合适；如果有效运动遍布全段，当前是显著加速。**本次没有逐帧视觉检查，不能认定是哪一种，也不应直接改成原速。** 固定模拟仍为 20Hz，配置时刻还会受到 Tick 量化，不能把上述浮点目标时长当作每次实战的精确测量值。

### 混合需要按具体片段区分

| 原图解释的边 | `TimeBlendData.mTime` | 当前混合 | 原图位置 |
| --- | ---: | ---: | --- |
| 第一拳 Start→Hit | 0.02 | 0.04 s | L5978 |
| 第一套被动拳 Start→Hit | 0.04 | 0.04 s | L5633 |
| 第二拳 Start→Hit | 0 | 0.04 s | L6062 |
| 第二套被动拳 Start→Hit | 0 | 0.04 s | L5891 |
| 两套被动 Hit→对应 Into_Idle | 0 / 0 | 0.04 s | L3209 / L12035 |
| Run_Base→Attack1_Start | 0.10 | 0.08 s，新动作入口 | L6623 |
| Attack1_Passive_Into_Idle→Attack1_Start | 0.15 | 连续攻击通常 0.04 s | L6533 |

第一套和第二套动作不能仅因为都叫 Start/Hit 就假设使用相同混合。反过来，也不应把某几个零值推广为“所有多段动作都关闭混合”。当前动作序列描述支持 `sequence_blend`，但这组普攻分段路径直接调用通用 `_play_attack_clip()`，没有逐边读取原图表；单改全局 `sequence` 不能准确表达上表。

## 2. 普攻到移动：专用素材选对了，退出时机仍需区分

原图 `Attack1_Passive_Hit / Attack2_Passive_Hit → Run_Base` 使用 `TransitionClipBlendData`，指向 `0xb6c6f5b7`（L5597 / L5609）。该节点资源 `260e6dfa2fc6805d` 对应 `sett_passive_into_run.anm`，正是当前第二、第四拳的 `Sett_Passive_INTO_Run_anm`。

这支持“被动拳 Hit 退出追击时走专用转跑”，不支持把它理解为必须先播完 Into_Idle。当前无下一目标时取消权威后摇、避免闪播 Into_Idle 的处理与这种表现路线相容，但取消时机是本项目自行制定的自动战斗规则。

当前 `attack_to_move` 根据攻击段索引选择；原图表以具体动画节点作为端点。因此值得检查：已经进入 Into_Idle 较久才追击时，是否仍适合重播同一个 Passive→Run。原图没有这两段 Into_Idle→Run_Base 的显式条目，但这不证明 LoL 不允许该切换。

第一、第三拳后选 `Run_Passive`：原图确有这个跑步节点和 Run 同步组（L573），但此图不足以还原外部何时请求它、何时解除。现有按拳序选择可以保留为简化，不能标记为已还原 LoL 的完整被动状态。

## 3. W：主片段正确，收尾存在可利用的原始路线

原图普通节点 `Spell2_BASE` 的资源 `5b9fce9af769233d` 对应 `sett_spell2.anm`，与项目 `Sett_spell2_anm` 一致。强化节点为 `Spell2_Strong`。

| 行为 | 原图证据 | 当前实现 | 建议 |
| --- | --- | --- | --- |
| 普通/强化选择 | `Spell2` 是 `ConditionFloatClipData`，输入 `ParBarPercentParametricUpdater`，强化项显式值 `0.8`（L753） | 豪意比例 ≥0.999 才选强化动作 | 原始参数与项目满豪意语义不同；保留满豪意规则，除非另行决定改变表现阈值。精确阈值比较方式仍需运行时证据 |
| W 入口 | Run_Base→普通为 0.10；→强化为 0.04（L3410 / L4580） | 两者都是 0.08 s | 可作为逐动作混合候选，不必追求数值机械一致 |
| 普通 W→跑步 | 经 `Spell2_Into_Run`（L2309） | 0.14 s 直接混合到 Run_Base | 有明确可研究的专用转场 |
| 强化 W→跑步 | 同样经 `Spell2_Into_Run`（L6308） | 0.14 s 直接混合到 Run_Base | 不是“强化没有可用 ToRun” |
| 普通 W→IdleReady | 经 `Spell2_Into_Idle`（L4712） | 直接回项目基础状态 | 项目基础待机是 Idle_Base，不能不加区分地照搬目标 |
| 强化 W→IdleReady | 经 `Spell2_Strong_Into_Idle`（L6233） | 同上 | 收势可以是可中断表现，不必扩大施法锁定窗口 |
| W→下一拳 | 普通/强化→Attack1_Start 都是时间混合 0.10（L6659 / L6677） | action_out 0.14 s 接排队攻击 | 不能每次 W 结束都强插 ToRun 或 Into_Idle |

`Spell2_Into_Run` 本身是参数化节点，不是一段固定动画。输入为 `LookAtSpellTargetAngleParametricUpdater`，样本为 -179、-90、中间未显式写值、90、179，对应左右转身与基础转跑（L837）。具体角度坐标、插值方式和缺省值仍需引擎或实战核验，不能仅凭名字认定就是鼠标点击角度。

其中基础节点 `0x6c5af74e` 哈希匹配 `Spell2_Into_Run_Base`，资源对应 `sett_spell2_into_run.anm`；项目已经包含 `Sett_Spell2_INTO_Run_anm`，也包含四个左右转身版本。缺的是选择与接入规则，不是素材。基础与转身节点还包含路径贴合事件、骨骼 mask、移速参数处理，不能保证仅播放 GLB 就复制 LoL 效果。

本项目不必实现五方向参数化混合。可以先验证“技能结束且确实移动→基础 ToRun→Run；能攻击→直接进入攻击；停住→基础待机或经核验的收势”。但必须检查实际终止姿态：当前普通 W 的 1.567 s 素材被缩到 1.4 s，强化 W 的 1.167 s 素材被拉到 1.4 s；原图不提供我们这两个窗口应在原始哪一帧结束的完整运行规则。不能简单把 1.567 s 的 ToRun 全段附加为新的权威锁定时间。

## 4. 声音与事件：已能证明动作归属，不能证明伤害时刻

| 节点 | 原图 SoundEventData | 当前出手池 | 判断 |
| --- | --- | --- | --- |
| Attack1_Start / Attack2_Start | `Play_sfx_Sett_SettBasicAttack_cast` | 第 1 / 3 池 | 对应正确（L913 / L929） |
| 两套 Passive_Start | `Play_sfx_Sett_SettBasicAttack2_cast` | 第 2 / 4 池 | 对应正确（L881 / L897） |
| Spell2_BASE | `Play_sfx_Sett_SettW_cast` | active:sustain | 对应正确（L150） |
| Spell2_Strong | `Play_sfx_Sett_SettW_maxed_cast` | active_strong:sustain | 对应正确（L722） |

以上声音事件未显式写 `mStartFrame`，不能把缺省字段冒充已验证的精确触发帧。Hit 节点另有 `Sett_BA_Swipe_01/02` 粒子事件与随动画变速标志，但这不是伤害事件；`mEndFrame = 60` 也不是“第 60 帧命中”。W 强化粒子有 `mEndFrame = 243`，更不能直接除以项目导入 30 FPS 当成施法时长，必须核对原引擎事件时间单位与节点时钟。

当前声音跟随权威动作/实际命中，未复制原动画事件时钟或完整 Wwise 生命周期。关联正确不等于完整时间同步已还原。`first_hit = 0.12`、W `impact_delay = 0.72` 未由本次动画图得到原始命中依据；应继续作为本项目玩法参数，并通过动作对齐验证它们的观感。

## 5. 适合本项目的后续验证

| 顺序 | 验证问题 | 可以保留的简化 |
| --- | --- | --- |
| 1 | 对照被动 Hit 原速、当前 0.32 s 整段加速，定位有效击打与持姿区，再决定裁剪或重排 | 不改四拳伤害、20Hz 权威、攻击命中间隔 |
| 2 | W 普通/强化完成后，分别查看继续攻击、追击、停住；比较当前直接混合与基础专用收尾 | 只做基础 ToRun，不复刻五方向混合与点击控制 |
| 3 | 比较四条 Start→Hit 与两条 Hit→Into_Idle 的原图混合值和当前统一值 | 没有已核验规则时继续使用通用 crossfade |
| 4 | 被动 Hit 中途退出、Into_Idle 早期/晚期退出分别检查 | 只覆盖项目实际发生的自动追击，无需实现玩家走砍 |

若验证后需要实现，优先补充数据驱动的“当前片段→目标片段”表现例外；具体 schema 设计另行确定。保留现有 locomotion + action、优先级和权威时间线，不引入完整 LoL 动画图解释器，不增加英雄专属 Unit 或动画中的伤害回调。

本次验证完成：序列/混合表结构解析、全部表键端点匹配、关键原始动画路径核对、GLB 时长读取、Godot 包装场景动画名和时长读取（无 SCRIPT ERROR）。未做：原版 LoL 动态操作实验、事件默认值与引擎算法复原、逐帧动作目视验收、实际音频试听。未改变运行行为，因此未执行完整机制回归；后续修改时按项目工作流进行回归与实际渲染验收。
