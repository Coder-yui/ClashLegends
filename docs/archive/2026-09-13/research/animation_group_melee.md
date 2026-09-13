# 近战卡原始动画表对照：盖伦、剑圣、格温、赵信

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

2026-09-12。只调整表现数据；四卡 gameplay、攻击/技能伤害时间线、默认 1 秒部署和 0.8 秒死亡均保持。节点解释依据 `AnimationGraphData`，资源路径通过原 WAD 的 hash 路径表解析，再与已导入 GLB 的动画列表对应。未恢复 Riot 播放器的骨骼遮罩、粒子、方向参数更新器和所有混合求值方式。

`mBlendDataTable` 的 u64 高/低 32 位分别按源/目标节点的 lowercase FNV1a32 对应；这一方向与已命名的 ToRun/ToIdle 引用交叉核对。它是素材层的可验证解释，不宣称获得原游戏引擎代码。原表没有明确记录的边继续使用本项目通用混合，不把整张图机械搬进卡牌。

## 来源与复查

原 WAD 根目录：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/`。没有改写此目录或已有工具提取库。

| 卡 | 读取的动画表 | 原始位置 |
| --- | --- | --- |
| Garen | `/tmp/clash-original-animation/garen.ritobin` | `Garen.wad.client` → `data/characters/garen/animations/skin0.bin` |
| MasterYi | `/tmp/clash-original-animation/masteryi.ritobin` | `/Users/czh/Tools/lol-asset-tools/verification/masteryi/data/characters/masteryi/animations/skin0.bin` |
| Gwen | `/Users/czh/Tools/lol-asset-tools/card_audio_batch/gwen/data/characters/gwen/animations/skin0.ritobin` | `Gwen.wad.client` → `data/characters/gwen/animations/skin0.bin` |
| XinZhao | `/Users/czh/Tools/lol-asset-tools/card_audio_batch/xinzhao/data/characters/xinzhao/animations/skin0.ritobin` | `XinZhao.wad.client` → `data/characters/xinzhao/animations/skin0.bin` |

下文行号均指此表。Garen/Yi 的临时文本可用现有 `/Users/czh/Tools/lol-asset-tools/bin/wadtools extract` 只提取上述 `.bin` 至临时目录，再用 `ritobin-tools convert` 重建；文件 hash 的名字用 `wadtools paths -x 'animations/.*\.anm$'` 从相同 WAD 只读获得。无新模型/纹理/音频资源导入。

## 盖伦

### 节点与资源

文件路径前缀为 `assets/characters/garen/skins/base/animations/`。

| 图节点（行） | 源资源 | Godot 动画 |
| --- | --- | --- |
| `Attack1`（9）、`Attack2`（41） | `garen_2013_attack_01.anm`、`garen_2013_attack_02.anm` | `Attack1`、`Attack2` |
| `Idle1_Base`（157）、`Run_Base`（273） | `garen_2013_idle1.anm`、`garen_2013_run.anm` | 同名 |
| `Spell1`（281）、`Run_Spell1`（490） | `garen_2013_spell1.anm`、`garen_2013_run_spell1.anm` | 同名 |
| `Spell3_0`（610） | `garen_base_spell3_0.anm` | `Spell3_0` |
| `Respawn_Base`（460）、`Death`（123） | `garen_2013_respawn.anm`、`garen_2013_death.anm` | 同名 |

### 采纳与保留

- 两段普攻是完整 `AtomicClipData`，不是 Start/Hit 序列；不因“所有英雄都应分段”而拆动画。
- `Attack2→Attack1` 为 0 秒（2296）。其他基础攻击入口没有同等明确的 TimeBlend 条目，保持通用策略。
- Q 从 Respawn / Idle / Run / Run_Spell1 / Attack1 / Attack2 / Spell1 进入均 0.1 秒（880、1588、1021、1678、1438、1468、1906）；逐源配置。`Spell3_0→Spell1` 为 0 秒（1279），单独保留例外。
- 审判 `Spell3_0` 从上述当前行为进入均为 0 秒（871、1009、1423、1456、1576、1669、1894）；退出到跑、两段普攻、待机、Q 同样为 0 秒（1216、1234、1237、1249、1279）。因此动作描述的 `blend_in / blend_out` 为 0，3 秒时长不变。
- `Spell3` 是朝技能目标角度选择的参数图（640–665），当前单位继续使用 0° `Spell3_0`，不移植额外方向轨道。
- Respawn 原片约 0.933 秒，Death 约 4.3 秒。维持现有部署/死亡时间适配；没有足够证据为死亡另定裁剪点。

## 剑圣

### 节点与资源

文件路径前缀为 `assets/characters/masteryi/skins/base/animations/`。

| 图节点（行） | 源资源 | Godot 动画 |
| --- | --- | --- |
| `0xd5c55cfd`（21） | `masteryi_2013_attack1.anm` | `masteryi_2013_attack1_anm` |
| `0x0d6139b0`（28） | `masteryi_2013_attack2.anm` | `masteryi_2013_attack2_anm` |
| `0x85dac0b3`（197） | `masteryi_2013_passive.anm` | `masteryi_2013_passive_anm` |
| `0x56f6d84b`（60）、`Run`（110） | `masteryi_2013_idle1.anm`、`masteryi_2013_run.anm` | `masteryi_2013_idle1_anm`、`Run` |
| `2013_Run_Haste`（261） | `masteryi_2013_run_haste.anm` | `2013_Run_Haste` |
| `Respawn`（658）、`Death`（49） | `masteryi_npe_spawn.anm`、`masteryi_2013_death.anm` | 同名 |

### 采纳与保留

- `Attack1 / Attack2 / Passive` 是 `ParallelClipData`（351–362）；各自一个身体片段与一个同资源、带遮罩/另一轨道的粒子拖尾层同时运行。后一层不是后续攻击阶段，因此保留当前完整三段选片，不错误拆成 Start/Hit。
- 明确恢复 `Attack2→Passive`（771）、`Attack2→Attack1`（777）、`Attack1→Passive`（933）的 0.1 秒混合。第三段出拳后的下一轮、普通/加速跑切换、Respawn 出口没有对应的明确专用条目，维持通用混合。
- 原 `Idle1` 有入场与长待机序列，未为这轮战斗修正额外引入闲置动作循环。
- 攻击间隔 0.7 秒、追加刀 +0.12 秒、高原血统倍率/持续时间保持；音频仍由权威事件触发，不受混合值影响。
- 部署/死亡原片分别约 2.667 / 1.7 秒，统一 1 / 0.8 秒的现有适配不变，不猜原 NPE 专用出场的截取点。

## 格温

### 节点与资源

文件路径前缀为 `assets/characters/gwen/skins/base/animations/`。

| 图节点（行） | 源资源 | Godot 动画 |
| --- | --- | --- |
| `Attack1`（8）、`Attack2`（79）、`Attack3`（803） | `attack1.anm`、`attack2.anm`、`attack3.anm` | 同名 |
| `0x0b87a8ad`（40）、`0x12d3e7d2`（46） | `idle.anm`、`run.anm` | `Idle_anm`、`Run_anm` |
| `Into_Run`（495）、`0x6082b70c`（905）、`0x708b3351`（894） | `into_run.anm`、`into_run_-90.anm`、`into_run_180.anm` | `Into_Run`、`INTO_Run_-90_anm`、`INTO_Run_180_anm` |
| `Attack1/2/3_To_Idle`（835、841、847） | `attack1/2/3_to_idle.anm` | 同名 |
| `Spell1_0`（247）、`Spell1_B`（1127）、`0x9ab169b5`（1175） | `spell1.anm`、`spell1_b.anm`、`spell1_c.anm` | `Spell1_0`、`Spell1_B`、`Spell1_C_anm` |
| `Spell1_C_To_Idle`（1276）、`0xf8fc4b70`（1282） | `spell1_c_to_idle.anm`、`spell1_c_to_run.anm` | `Spell1_C_to_Idle_anm`、`Spell1_C_to_Run_anm` |

### 采纳与保留

- 目前使用的基础行为→三段普攻均为 0 秒；当前图 109 条明确 TimeBlend 入口中只有 `Stunned` 为 0.05 秒（三目标在 22768、22777、22786），其余 108 条为零。用三个目标通配规则和精确 Stunned 例外表达，保留未来启用该片段时的原规则。
- 当前行为→`Spell1_0` 为零（2023、2035、2083、2143、2839、4321、5053），Q 动作 `blend_in = 0`。原 `Spell1_0→Spell1_B`（7357）、`Spell1_B→自身`（7366）、`Spell1_B→Spell1_C`（9559）均零，确认此前人工校准的内部无混合成立；四档 1.5 秒时长、裁剪及各剪切命中点保留。
- 三段攻击的 ToRun 是参数图：`Attack1_To_Run`（853）、`Attack2_To_Run`（916）、`0xdfb36588`（946）。它们在目标角度 0° 的分支依次为 `Into_Run`、`0x6082b70c`、`0x708b3351`。此前第二段使用 Into_Run 对应了该参数图的 +90°，现选择 0° 对应片段。
- 本项目单位整体已经跟随移动/攻击方向转正，采用原图 0° 分支是有明确条件的简化；未实现 `LookAtSpellTargetAngleParametricUpdater` 和 `TURN` 的连续方向混合。需要渲染检查第二拳之后向前、转侧面移动；不能把这项称为完整复刻方向求值。
- 对应三条普攻→转跑入口均 0.05 秒（2329、5674、5767）；部署/普通待机→Into_Run 为 0.05 秒（5395、2347）。转跑片尾没有单独明确 TimeBlend 的边仍用项目 sequence 默认值，不自行填零。
- 三段普攻→`Idle_anm` 的专用出口分别为 Attack1/2/3_To_Idle（5005、5011、5017）；采用逐源路由，新动作可打断。入出口没有原数值的边继续用默认 sequence 混合。
- 最终 Q →跑使用 `0xf8fc4b70`（8206、9973），片尾→Run 为零（10165）；最终 Q →Idle 使用 `Spell1_C_To_Idle`（8176），实际 0°片段到该收勢的边为零（10282）。仅由最终 C 片段启用，不把整条技能行为无条件接同一出口。
- Respawn、Death 的截取点不确定，保持 1 秒部署/0.8 秒死亡。随机 Idle/Run、特殊被动分支、VFX 与额外朝向轨道暂不迁移。

## 赵信

### 节点与资源

文件路径前缀为 `assets/characters/xinzhao/skins/base/animations/`。

下表记录原表节点与本地片段的候选对应，**不等于最终启用的播放序列**；原表普攻候选未通过当前导出模型的接缝验收，最终配置见下文。

| 图节点（行） | 源资源 | Godot 动画 |
| --- | --- | --- |
| `Attack1_Hit`（670）→`0x96162dae`（676） | `attack_aa_01_hit.anm` → `attack_aa_01_settle.anm` | `Attack1_Hit` → `Attack_AA_01_settle_XinZhaoRework_anm` |
| `Attack3_Hit`（721）→`0xef307e78`（727） | `attack_aa_04_hit.anm` → `attack_aa_04_settle.anm` | `Attack3_Hit` → `Attack_AA_04_settle_XinZhaoRework_anm` |
| `0xdaf2afd9`（746）→`0xaa4233eb`（767） | `passive_aa_01_hit.anm` → `passive_aa_01_settle.anm` | `Passive_AA_01_hit_XinZhaoRework_anm` → `Passive_AA_01_settle_XinZhaoRework_anm` |
| `0x9ae3e840`（641） | `passive_aa_01.anm`，`startFrame = 51` | `Passive_AA_01_XinZhaoRework_anm`（最终保留既有普攻选片） |
| `0xba836ecf`（548） | `passiveaa_to_run.anm` | `PassiveAA_to_Run_XinZhaoRework_anm` |
| `Spell4`（116）、`Spell4_To_Run`（397） | `spell4_v2.anm`、`spell4_torun.anm` | 同名 |
| `RunIn`（298）、`RunBase`（59）、`IdleBase`（468） | `runin.anm`、`runbase.anm`、`idlebase.anm` | 同名 |

### 采纳与保留

- 最终只采纳两项独立规则：主动 Spell4 入口的 77 条明确 TimeBlend 均为零，故 `active.blend_in = 0`；原被动转跑→RunBase 为 0.1 秒（2510），且对应现有第三段专用出口，故保留这一精确边。不改变主动/部署实际效果在起始帧结算的玩法。
- 原第一段序列 `Attack1_BASE`（682）使用 AA01 配对；第三种普通攻击 `0x0c656e32`（733）使用 `Attack3_Hit → AA04_settle`；`Attack_Passive`（779）使用 `passive_aa_01_hit → passive_aa_01_settle`。三组内部混合在原表均为零（2888、3806、3335）；三种出手目标各 77 条已记录 TimeBlend 也均零。以上是有来源的候选，但没有证明当前导出资源能按相同规则拼接。
- 实际 GUI 连续帧检查否决了普攻候选：从攻击开始 300 到 333ms，第一击由低身横枪突变为站立举枪，被动由上举长枪突变为枪尖朝下的跨步姿势；第二击也存在端点差异。双方阵营均复现，相关联系图为 `/tmp/clash-original-animation-review/xin_blue_detail_0.jpg`、`xin_blue_detail_1.jpg` 及 red 对应图。不能把“原表数值为零”当作本地导出 GLB 已无缝的证据。
- 按用户“不确定先不改”，已撤回整个普攻候选：仍使用 `attack = [Attack1_Hit, Attack3_Hit, Passive_AA_01_XinZhaoRework_anm]`、`attack_hit = [Attack_AA_01_settle_XinZhaoRework_anm, Attack_AA_03_settle_XinZhaoRework_anm, ""]`、`attack_hit_duration = 0.6`，不启用 `attack_reference_interval`，普攻入口和 Hit→settle 继续采用通用策略。AA04 配对也暂不交付；需要先核对原表版本、导出片段端点与播放器求值。保留旧配置不代表旧配对已被证明等同原版。
- 原被动 Hit 与 settle → RunBase 都使用 `0xba836ecf`（3836、3827），Hit→专用转跑为零（3839）。由于最终仍使用旧完整 Passive，未采纳这条新 Hit→转跑零混合；现有完整 Passive→转跑保持通用 sequence 0.04 秒，只有转跑→RunBase 的 0.1 秒明确边保留。
- 普通 AA01 / AA04 收势→RunBase 的原出口为 `0xe7f0db78`（3821、3809），其内容是 `Runbase_engaged × 4 → RunEngaged_toRunBase`（326）。当前单片段攻击出口不能等价表达该序列，暂保留既有 RunIn，不擅改通用播放器。
- 原 RunIn 有 `EndFrame = 23` 与 `mTickDuration = 0.037037037`（298–311）；此次不猜它与当前导出 GLB 帧边界的关系。Spell4→Idle 虽有专用出口（1871），原片尾与该片段起姿不同、现有 Spell4 全长已压到 1 秒，暂不追加可能重复收势的出口。
- 部署特殊新月护卫、主动 1 秒施法、0.8 秒死亡均保持，未使用普通 Respawn 取代部署技能。

## 音频与验证边界

四卡没有改权威动画/技能事件开始、伤害结算或结束的时间；没有新增动作音频入口，普攻序号与当前音频分段池仍一一对应。赵信 AA04 普攻序列的原粒子事件名为 `XinZhao_BA_02`（733–744），与现有第二段 BasicAttack2 音频对应；被动仍是第三段 PassiveCritAttack。格温新增的普通 ToIdle 与 Q ToIdle/ToRun 节点无新的 SoundEvent。现有完整 Q 音频不会因其已锁定的 1.5 秒时序变化而错位，因为本轮未改时序。

已执行 headless 的全 CardDB validator 与四个真实包装场景加载，检查新增/调整的每个 clip、混合源/目标、转场片段均存在，结果 0 项错误。Godot macOS 在受限环境打印系统 CA 证书读取警告；没有 GDScript 错误。随后独立目视复查总任务生成的四卡双阵营实际 GUI 截图，以及 Gwen/Xin 的接缝连续帧：Gwen 新转跑/待机/Q 出口可保留；Xin 候选暴露端点跳变，已按上文撤回。未主观试听音频；完整机制与撤回后的最终渲染由总任务统一验收。

最终渲染覆盖双方阵营的各普通/强化攻击、各档主动、移动/待机出口以及部署/死亡；Gwen 与 Xin 另有连续接缝帧。Gwen 第二/第三拳转跑、三段普攻待机收势、四档 Q 出口均已查看；Xin 最终使用保留的前两段分段普攻与第三段完整 Passive，普攻/技能后移动仍走原路线。攻速变化、真实命中以及新攻击打断收势由统一机制回归验证，未把静态表现夹具当作实战音画同步或所有可能入口的验收。部署/死亡只回归既有时长，不把本次未修改当作原版完整复刻。

### 2026-09-13 赵信第三击后续修正

未恢复之前有姿态跳变的独立 passive hit/settle 配对。本次将完整 Passive 同一源片段切为 0–0.3 与 0.3–3.0 秒连续播放，前者按真实前摇、后者按收势时长适配；双方阵营渲染复核和机械回归通过。
