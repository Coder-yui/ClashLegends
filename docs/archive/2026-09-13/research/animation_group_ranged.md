# 远程四卡：原始动画表核对与采纳记录

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

日期：2026-09-12。范围：艾希、赏金猎人、提莫、卡牌大师当前实际使用的动画；不修改 gameplay、音频素材、权威时间线、部署或死亡时长。

## 取证方法与边界

原表来自本机外部 LoL 素材库；只读 WAD，没有迁移或重导入模型。资源哈希通过 `wadtools list -F json` 在对应 WAD 内反查实际 `.anm` 路径；导入时长由 GLB accessors 与 Godot AnimationPlayer 读取相互核对。

u64 混合键拆为高/低 32 位，字符串使用小写 FNV-1a。沿用腕豪审查的解释：高位为来源、低位为目标。该方向与本组 `Spell1→Idle`、`Run→Idle` 的转场内容一致，但未取得 Riot 播放器代码。`TimeBlendData {}` 未显式给出 mTime 时不假定为 0；`mCascadeBlendValue = 0` 也不当作所有边都硬切。原图没有一条边不表示禁止切换。

Godot 导入名与图节点名可能不同：依据实际资源文件和当前 GLB 名称匹配，不能只用动画名猜测。本文的秒数如无特别说明为导入片段时长，不宣称是 LoL 实战允许的行动窗口。

## 来源

WAD 根目录：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/`。以下行号指对应文本原表。

- `ashe`：`/tmp/lol-ranged-animation/ashe/data/characters/ashe/animations/skin0.rito`；26 个图节点、76 条混合表项。
  - 文本 SHA-256：`e9786115ac1c47bf53498da182539ed6bc1fbcfd82e93edccd9353bfa748107f`。
- `missfortune`：`/tmp/lol-ranged-animation/missfortune/data/characters/missfortune/animations/skin0.rito`；30 个图节点、45 条混合表项。
  - 文本 SHA-256：`f86bbb5e039cc4d3f46a4d5cc2347ab2e7ffc374cbaf25b88079b9c3a5b82d83`。
- `teemo`：`/Users/czh/Tools/lol-asset-tools/card_audio_batch/teemo/data/characters/teemo/animations/skin0.ritobin`；71 个图节点、293 条混合表项。
  - 文本 SHA-256：`c169f0f3ab859652b2498251cb7106abc42b2e374da06ef7932bd84e682b3816`。
- `twistedfate`：`/Users/czh/Tools/lol-asset-tools/card_audio_batch/twistedfate/data/characters/twistedfate/animations/skin0.ritobin`；39 个图节点、34 条混合表项。
  - 文本 SHA-256：`20aaf81e9d1656fada4ba2ab8e3bfa0d7e453c2c3738228b64d03da959942f2b`。

Ashe/MissFortune 文本是本轮在 `/tmp/lol-ranged-animation/` 中由对应 `data/characters/<id>/animations/skin0.bin` 转换所得；原 WAD 不变。Teemo/TwistedFate 使用既有 card_audio_batch 只读提取结果。

## 艾希

| 原图节点（行号） | 原始资源末段 | 项目片段 / 时长 |
| --- | --- | --- |
| Attack1 / Attack2（9 / 155） | ashe_attack1.anm / ashe_attack2.anm | Attack1 / Attack2，各 2.133 s |
| Idle1（27） | ashe_idle1.anm | Idle1，9.333 s |
| Run（64） | ashe_run_walk.anm | Run，7.200 s |
| Spell2（167） | ashe_spell2.anm | Spell2，1.833333 s |

**采纳**：W 的原片长度与权威 cast_duration 同为 1.833333 秒，现有描述却要求 1 秒播完，之后持末帧等待权威施法结束；改为 1.833333 秒原速播放。`impact_delay = 0.62`、普攻 first_hit 0.45、攻击间隔、技能锁定和音频释放时刻均保持。不是把原片长度反推为伤害时刻。

**保留**：原图大量入口指向 Spell1_In（L225–450），它属于 Spell1/Q。Spell1→Run 的 0.4 秒也属于 Q（L360–368），不能移用到当前 W。当前 Attack1/2、Spell2 的常用出入口没有可采纳的明确专用时长；现有入口/出口混合保留。图中没有 Respawn，继续 Idle1 部署及 0.8 秒死亡。没有基于 Run/Run2/Run3 名称自动改变移速选择。

## 赏金猎人

| 原图节点（行号） | 原始资源末段 | 项目片段 / 时长 |
| --- | --- | --- |
| Attack1 / Attack2（9 / 30） | missfortune_attack1.anm / missfortune_attack2.anm | Attack1 / Attack2，各 2.667 s |
| Run_Base / Run2（149 / 156） | missfortune_run.anm / missfortune_run_passive.anm | Run / Run2，各 0.800 s |
| Idle1_Base（125） | missfortune_idle1.anm | Idle1_Base，1.333 s |
| Idle_In（389） | missfortune_idle_in.anm | Idle_In，0.733 s |

**采纳**：原图 `Run_Base→Idle1_Base`（L475）和 `Run2→Idle1_Base`（L499）均为 `TransitionClipBlendData(Idle_In)`；项目配置 `Run>idle` 与 `Run2>idle`，待机前先播可打断的 Idle_In。原图 Run 条件读取 MissFortuneStrutMax 并允许中途换片（L446–455），与现有 haste_move 的意图一致，保留现有 Buff 触发。

**保留**：当前普通攻击间没有明确的非默认混合依据；0.4 秒边来自 Attack1/2↔Crit（L490 / 508 / 535 / 538），不引入未使用的暴击动作。Idle_In 原节点还写有 mTickDuration（L392），但本轮不在缺少帧时钟完整语义和原版播放参照时臆造速率规则；使用已导入素材时钟和通用片段混合。Respawn / 0.8 秒死亡均不改。

## 提莫

| 原图节点（行号） | 原始资源末段 | 项目片段 / 时长 |
| --- | --- | --- |
| Attack1→0xafb03da9 / 0xbb123153（806 / 9 / 815） | attack1.anm | Attack1_ASU_Teemo_anm，0.333 s |
| Attack1_ToIdle（301） | attack1_toidle.anm | Attack1_ToIdle，1.667 s |
| Spell1（145） | spell1.anm | Spell1，0.300 s |
| Spell1_ToIdle / Spell1_ToRun（321 / 328） | spell1_toidle.anm / spell1_torun.anm | 同名，3.633 / 0.667 s |
| Run_Base / 0x873063aa（138 / 345） | run.anm / run_in.anm | Run_Base / Run_In_ASU_Teemo_anm，0.633 / 0.767 s |
| Idle_In（336） | idle_in_.anm | Idle_In，2.233 s |
| Respawn / 0x68538d8e（595 / 756） | spawn.anm / spawn_toidle.anm | Respawn / Spawn_toIdle_ASU_Teemo_anm，1.467 / 1.433 s |

Attack1/Attack2 的 E 条件只替换粒子事件，实际资源均为同一个 attack1.anm；两个 ToIdle 节点也引用同一资源（L301 / 308）。因此保留项目单组合循环，不引入看似不同的重复攻击。

采纳的路径与来源：

| 项目路径/规则 | 原表证据 |
| --- | --- |
| 普攻 Start→ToIdle 混合 0.05 s | Atomic 来源 L2026；逻辑 Attack1 来源 L2020 |
| 普攻 Start/ToIdle→下一普攻 Start 混合 0.05 s | L2074 / 2077 / 2080 |
| 当前可达来源→Spell1 混合 0.05 s | L1324 / 1327 / 1351 / 1354 / 1366 / 1369 / 1372 / 1375 / 1378 |
| 普攻 Start→Idle 经过 Attack1_ToIdle | L1513 |
| 普攻 ToIdle→Idle 经过 Idle_In | L1489 |
| Run_Base / Run_In 原子片段→Idle 经过 Idle_In | L1498 / 1510 |
| Spell1→Idle 经过 Spell1_ToIdle | L1948 |
| Spell1_ToRun→Idle 经过 Idle_In | L1522 |
| Respawn→Idle 经过 spawn_toidle.anm | L1924 指向 0x68538d8e，资源在 L756 |

**速率调整**：取消把 Attack1_ToIdle 的 1.667 秒强压到 0.75 秒；改用 `attack_reference_interval = 1.0`，基础间隔下原速播放后摇，由下一次权威普攻/移动打断。这沿用腕豪已经验证的可中断收势方案，不要求权威后摇等待素材播完。Start 仍在 0.25 秒完成离弦，攻击间隔仍为 1 秒；调整基础间隔和局内攻速 Buff 继续由通用时钟适配。

**保留**：Run_In 是根据 TotalTurnAngle 的 -90/中间/90 三个节点选择（L367），不能仅凭原图确定 Godot 朝向坐标与插值规则，仍选已有直向起步。Spell1_ToIdle/ToRun 有同名同步组（L323 / 331 / 1219），保留既有强化转跑入口，不宣称还原同步相位；原图 ToRun→Run 还可经 Run_In（L1393），本轮不强串另一条可能重复起步的片段。1 秒部署仍播放完整 Respawn；只有部署完确实闲置才接新 Spawn_toIdle，任何新攻击/移动可以打断，不加部署锁。0.8 秒死亡不改。

## 卡牌大师

| 原图节点（行号） | 原始资源末段 | 项目片段 |
| --- | --- | --- |
| Attack1/2/3/4（9 / 27 / 123 / 141） | twistedfate_2012_attack1/2/3/4.anm | Attack1/2/3/4 |
| Spell3（104） | twistedfate_2012_attack1.anm | Spell3（同 Attack1 骨骼动作） |
| Spell1（92） | twistedfate_2012_spell1.anm | Spell1，0.9677415 s |
| 0x54d02d78 / RAW_Idle1（184 / 71） | twistedfate_2012_idle_enter.anm / twistedfate_2012_idle1.anm | 同资源导入名 |
| Run1（263） | twistedfate_2012_run.anm | Run1，1.000 s |

**保留当前配置**：原图 Idle1 顺序是 idle_enter→RAW_Idle1（L191），现有部署/待机片段有来源支持。当前五击固定选择与第五击加伤是项目玩法，不从图里改为随机或缩为四击。34 条混合表项主要为 Death 及转身/待机节点；没有当前普攻/Wild Cards→Run1/RAW_Idle1 的明确可采纳边。没有显式 mTime 的条目不填 0。Spell1 已匹配原片长度，0.25 秒权威出手与技能时长保持。Walk/Run1 的 300/350 阈值属于 LoL 移速量纲（L243–255），不直接映射为 px/s。

## 验证与渲染交接

四卡 Godot 实际资源名称契约均通过；Ashe 的 Spell2 实测长度 1.833333373 秒与新表现时长相符，Teemo 的 ToIdle 实测 1.666666627 秒。临时读取脚本/日志在 `/tmp/lol-ranged-animation/check.gd` / `godot.log`。另外 `/tmp/lol-ranged-animation/routes.gd` 的 16 项实际播放器检查通过：Ashe W 原速、MF 两种 Run 停步与 Idle_In 完成、Teemo 七种来源 Idle 路由、原速 ToIdle、0.05 秒缝以及下一次攻击打断。日志为 `routes.log`。这些检查是 headless，不冒充渲染目视验收；全套机制及下面渲染场景由主任务统一执行。

1. 艾希双阵营：0.62 秒 W 释放与箭的出手一致，约 1.833 秒后接攻击/移动，不再第 1 秒后持姿；普通 Attack1/2 不变。
2. MF 双阵营：普通 Run 停步和 W 加速 Run2 停步都进 Idle_In，起步/新攻击可中断，W 到期仍立即恢复 Run。
3. 提莫双阵营：普通起手/毒针/ToIdle/下轮起手，0.5×/1×/2× 攻速下后摇不被强赶完；Q→继续攻击、Q→移动与原有路线一致。
4. 提莫无目标部署：1 秒后进入 Spawn_toIdle；收势期间立即放置目标应进入普攻，走路应进入 Run_In。普通攻击结束或停步闲置时检查 Idle_In 无倒播/明显跳姿。
5. TF 双阵营：部署、五段普攻、万能牌到移动/攻击及 0.8 秒死亡原样通过，无新玩法变化。

音频核对：本轮新接 MF Idle_In、Teemo Idle_In/spawn_toidle 原图节点没有 SoundEventData，不加虚构音效。Teemo attack1 原表粒子在第 10 帧（L13）与 0.333 秒原片结束相符，Start 仍压到 0.25 秒，权威弹体/音频出手时刻保持。Ashe 使用既有 0.62 秒 active:release，TF 和 MF 事件不改；音频只按已有权威事件触发，不由动画回调。

## 整合目视结果

实际双阵营渲染及连续出口帧确认：MF 普通/加速 Run→Idle_In、Teemo Spawn_toIdle 与普通停步/ToIdle→Idle_In 可用；Ashe 和 TF 当前片段及出口未见模型/选片错误。最终工具扩大取景，重拍了原先被裁掉的弓尖、跳跃和死亡姿态。

Teemo 原有强化 `Spell1_ToIdle→Spell1_ToRun` 在 0→33 ms 样本间存在明显高度变化，随后再次翻身起跳；强化直接转 Idle 也会快速混到落地。原图同步组尚未移植，这部分按“不确定先不改”保持，不声明已经复刻其相位衔接。相应连续帧在 `/tmp/clash-original-animation-review/contacts/seams/teemo_red_base_empowered_exit_move.jpg`，全卡最终结果见 [整合报告](all_cards_animation_comparison.md)。
