# 凤凰、凤凰蛋、龙王与纳尔原始动画复核

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

日期：2026-09-12。范围是当前卡牌实际使用的普通攻击、持续吐息、技能、移动、变形与生死入口。只改表现配置；伤害、攻速数值、施法/变形锁定窗口、部署时长与死亡播放时长均保留。

## 来源与解释边界

以下缩写对应本地原始图，表内 L 为对应图的一基行号：

- **A**：`/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/card_audio_batch/anivia/data/characters/anivia/animations/skin0.ritobin`
- **E**：`/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/card_audio_batch/anivia/data/characters/aniviaegg/animations/skin0.ritobin`
- **S**：`/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/card_audio_batch/aurelionsol/data/characters/aurelionsol/animations/skin0.ritobin`
- **G**：`/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/card_audio_batch/gnar/data/characters/gnar/animations/skin0.ritobin`
- **B**：`/Users/czh/Projects/Clash Legends/ClashLegends-开发素材库/04-中间产物/素材加工/card_audio_batch/gnar/data/characters/gnarbig/animations/skin0.ritobin`

WAD 均来自 `/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/`，分别是 `Anivia.wad.client`、`AurelionSol.wad.client`、`Gnar.wad.client`。用本地 `wadtools list --hash … -F json` 核对图内资源哈希到原始 `.anm` 路径，再通过 Godot 实际加载五个包装场景核对导入名称。

五图分别有 21/2/108/96/70 个片段节点、20/2/1583/251/345 个混合条目。沿用腕豪复核的方法，u64 高/低 32 位按源/目标解释，字符串以小写 FNV-1a32 匹配。此解释有图结构支持，但未取得 Riot 播放器源码；未出现某条边不代表零混合，也不代表切换禁止。TimeBlendData 空结构的缺省值没有被当作显式 0。

图中的帧裁剪、骨骼蒙版、并行层与同步组不等于 Godot 播放一个完整 GLB 片段。对需要这些语义才能正确复现的内容，保留当前实现并记录原因。

## 凤凰与蛋

凤凰的 Attack1/Attack2（A L9/16）、Idle1（L56）、Run（L99）、Spell4（L123）、Death（L43）均为单一 AtomicClipData，不需要拆出猜测的 Start/Hit。蛋图只有 Death（E L9）与 Idle1（L15）。

| 实际边 | 原表时间 | 来源 | 改动 |
| --- | ---: | --- | --- |
| 凤凰 Run→Death | 0 | A L194 | 精确零混合 |
| 凤凰 Attack1/Attack2→Death | 0 / 0 | A L197/200 | 精确零混合 |
| 凤凰 Idle1→Death | 0 | A L218 | 精确零混合 |
| 凤凰 Spell4→Death | 0 | A L236 | 精确零混合 |
| 蛋 Idle1→Death | 0 | E L26 | 精确零混合 |

凤凰和蛋原图均没有 Respawn 节点，因此继续用 Idle1 部署；蛋的落地、孵化升起是项目的表现过渡。死亡保留凤凰 2.4 秒、蛋 1.066667 秒，不改变替身和复活规则。其余普攻、技能、待机和移动之间没有明确的表项，保留通用混合。冰雪风暴仍为 0.72 秒命中、1.166667 秒施法。

## 龙王

原图 Run_Base 是 `Run1B→Run1C→Run1D→Run1A` 的 SequencerClipData（S L458），当前顺序本来就正确。

| 实际边/路径 | 原表 | 来源 | 采纳方式 |
| --- | --- | --- | --- |
| RunIn→Run1B | 0 秒 | S L5099 | 精确混合 |
| Run1B→C、C→D、D→A、A→B | 均为 0 秒 | S L4274/4205/4346/4127 | 仅实际循环相邻边零混合 |
| Spell1_2Run→Run1B | 0.6 秒 | S L4076 | 精确混合；其余目标 Run 的 0.1 秒不混为一谈 |
| Idle1_Base→吐息 newtst | 0 秒 | S L6194 | 精确混合 |
| Respawn/RunIn→newtst | 0 / 0 秒 | S L6221/6284 | 精确混合 |
| Run1A/B/C/D→newtst | 均为 0 秒 | S L6227/6230/6233/6236 | 精确混合 |
| Spell1_2Run/Spell1_2Idle→newtst | 0 / 0 秒 | S L6302/6296 | 精确混合 |
| Spell4/当前强技能资源→newtst | 0 / 0 秒 | S L6353/8414 | 精确混合 |
| newtst/loop→Idle1_Base | 经 Spell1_2Idle | S L7343/7331/7337 | 按实际来源配置待机收势 |
| 常用状态→两种 R | 均为 0.25 秒 | S L5879、5912–5921、6143–6152、7664；L7715、7751–7760、7850–7862 | 两个 action 的 blend_in=0.25 |

原图 newtst 的节点名是 `0xd5fd0ee8`。Spell1（S L2313）依次选择它与循环选择器 `0x3523eead`；循环候选 `0x53fa2579`/`0x50fa20c0` 指向同一个 loop 文件的不同帧区。当前完整循环资源继续使用，避免未核对原始帧时钟就裁错区间。

吐息→Idle 的收势长约 1.066667 秒，作为可中断表现播放。权威停止攻击时即停止伤害和光柱；新攻击/追击不需要等收势结束。通用持续攻击状态分支需通过 `_transition_to_basic_state` 读取这些来源路由，而非直接 `_play_state`。

以下内容明确保留：

- new_looptoin 资源确实存在（S L2684），但图中没有确认当前“原地换目标→new_looptoin→newtst”的入口/内部边；该自动战斗约定和通用混合保持。
- 原表普通 Spell4 主体只用帧 10–16（S L2206），其 ToRun 从帧 18 接续（L2885），ToIdle 从帧 17 接续（L1047）；另一个 R 主体为帧 6–23（L2727），ToRun 从帧 24（L2787），ToIdle 从帧 2（L2774）。项目当前已播放整个 1.933333/1.9 秒资源，不能在结束后再从原表的中间帧重放收尾。因此保留 R 退出路线、施法及命中窗口，不仅凭 ToRun/ToIdle 名字强接。
- Run1A/C→IdleIn、B/D→Idlein2 有明确过渡条目（S L4136/4211/4286/4361），但导入两个资源均为 9 秒，存在路径贴合事件；此次未完成长片段动作区间核验，保留直接待机。
- 移速条件、左右旋转加法层、同步组和循环随机变体不移植；部署仍截取 Respawn 前 0.5 比例，死亡仍 0.8 秒。

## 纳尔两种形态

小纳尔 Attack1/2 是 AttackSpeedParametricUpdater 的条件选择（G L733/745），基础与 Fast 又各由下身/上身并行片段组成；当前 Gnar_Attack1/2_anm 是基础文件。大纳尔 Attack1/2 是同源主体与上身轨道并行（B L306/309）。单播放器完整骨骼片段保留，不把并行节点误拆成先后动作。

| 实际边 | 原表时间 | 来源 | 改动 |
| --- | ---: | --- | --- |
| 小 Run1_In→Run_Base | 0 | G L1285 | 精确零混合 |
| 小 Attack1→Attack1/Attack2 | 0 / 0 | G L1856/1850 | 精确零混合 |
| 小 Attack2→Attack1/Attack2 | 0 / 0 | G L1540/1534 | 精确零混合 |
| 大 Run_In→Run_Base | 0 | B L761 | 精确零混合 |
| 大 Attack1→Attack1/Attack2 | 0.1 / 0.1 | B L1637/1622 | 精确混合 |
| 大 Attack2→Attack1/Attack2 | 0.1 / 0.1 | B L1082/1064 | 精确混合 |

大纳尔 `Attack_Turret`（B L445）按攻速条件在 `0x4de41080` 普通文件与 `0x1377fdf7` Fast 文件之间选择，Fast 的参数是 1.3；原表没有“普通→Fast 交替”序列。项目取消此前的交替，基础建筑攻击只用 `GnarBig_Turret_Attack01_anm`，Fast 留在素材库。基础攻速 1/1.15≈0.87；未来 Buff 仍可通过通用播放倍率适配，此次不复刻 Riot 参数比较/中途切换语义。

变形沿用原表支持的叠加结构：

- 大纳尔 Rage（B L89）= Rage_Scale 加移动条件选择的 Rage_Stop/Rage_Move（L58）；本项目变形锁移动，采用已烘合的 Rage_Stop 版本合理。
- 主动变大（B L139）= `0x3c537b25`（GnarBig_Spell2_Tran_anm）加 Rage_Scale；保留 `gnar_runtime/Rage_Spell2_Transform`。
- 小纳尔 Revert（G L313）= Revert_Scale 加两条同源主体层；保留 `gnar_runtime/Revert_Transform`。

缩放层的显式零混合不可泛化到完整模型切换。现有变形时间、统一 0.8 秒技能命中、技能 1.2 秒、部署时长、小形态死亡 0.8 秒及大死亡 0.27 秒接小死亡 0.8 秒均未变。大 Run 图只列 Run_Base（B L328），Run_In 有资源与出口、却缺上游触发证据；本轮保留项目入口，不据此断言原版每次移动都播 Run_In。

## 声音与验证

此次混合/收势不新增权威事件，普攻、离弦、命中、持续吐息起止、技能和死亡音频触发点均沿用。四卡 gameplay 和 audio 与修改前深比较一致（大纳尔 gameplay 域内的 visual_animations 除外）。蛋仍为已登记的静音对象。

大纳尔攻击建筑一直复用普通攻击的两组挥击池；原图两个 Turret 节点没有 SoundEventData，不能声称已确认逐段专用建筑挥击音。改成普通建筑动作不改变其声音触发时刻，暂保留共享攻击音。混合表本身也不提供伤害/音效命中的权威时间依据。

本组已完成五个场景的 Godot headless 动画名/时长读取、四卡及大形态的素材契约与 visual schema 检查、非表现字段/音频深比较。检查脚本未报 GDScript 错误；沙箱下系统证书读取有 macOS 环境提示。全套机制及实际渲染由本次全卡整合统一执行，本报告不以 headless 检查代替目视验收。

整合渲染重点：龙王 Run 循环零混合、吐息入口、Spell1_2Run→Run1B 的 0.6 秒混合、吐息到 Idle 的可打断收势、两种 R 从吐息/移动进入；纳尔两形态普攻及建筑普攻、变形后转攻击/移动；凤凰最终死亡和蛋被击破的零混合入口。两阵营均需查看，部署/死亡裁剪维持已有视觉基线。

## 选定节点到原始文件与导入资源

下列原始路径省略统一前缀 `assets/characters/<角色>/skins/base/animations/`；纳尔两种形态的路径通过各自图的资源哈希核对。运行时合成 gnar_runtime 另见上文叠加关系。

| 图/行 | 原始节点 | 文件哈希 | 原始文件 | Godot 片段 |
| --- | --- | --- | --- | --- |
| A L9 | `Attack1` | `0xbabe2520c8821390` | `anivia_attack1.anm` | `Attack1` |
| A L16 | `Attack2` | `0x7513bb5b27ed6889` | `anivia_attack2.anm` | `Attack2` |
| A L56 | `Idle1` | `0x7e141f1fa8a06560` | `anivia_idle1.anm` | `Idle1` |
| A L99 | `Run` | `0xf603120819224527` | `anivia_run.anm` | `Run` |
| A L124 | `Spell4` | `0xbb6b8ac549a9e4d9` | `anivia_spell4.anm` | `Spell4` |
| A L43 | `Death` | `0x65981ab5fa5ba7d3` | `anivia_death.anm` | `Death` |
| E L15 | `Idle1` | `0xd8be97338dcc531b` | `rebirthegg_idle1.anm` | `Idle1` |
| E L9 | `Death` | `0xaa1a88cdfa3321d6` | `rebirthegg_death.anm` | `Death` |
| S L232 | `Idle1_Base` | `0x4d193e944728cd8e` | `aurelionsol_idle1.anm` | `Idle1_Base` |
| S L913 | `RunIn` | `0xe927016ca89cff5f` | `aurelionsol_runin.anm` | `RunIn` |
| S L303 | `Run1A` | `0x33cd1e541e0e2e20` | `aurelionsol_runa.anm` | `Run1A` |
| S L333 | `Run1B` | `0xe48424adf938cf44` | `aurelionsol_runb.anm` | `Run1B` |
| S L363 | `Run1C` | `0x222c755926a784c6` | `aurelionsol_runc.anm` | `Run1C` |
| S L393 | `Run1D` | `0x237533849957df2` | `aurelionsol_rund.anm` | `Run1D` |
| S L2263 | `0xd5fd0ee8` | `0x2ee8404e93246e` | `aurelionsol_spell1_newtst.anm` | `AurelionSol_Spell1_newtst_anm` |
| S L2352 | `0x53fa2579` | `0x9fb6fdf3b3c7f8d0` | `aurelionsol_spell1_loop.anm` | `AurelionSol_Spell1_loop_anm` |
| S L2422 | `0x50fa20c0` | `0x9fb6fdf3b3c7f8d0` | `aurelionsol_spell1_loop.anm` | `AurelionSol_Spell1_loop_anm` |
| S L2684 | `0xadcdaa87` | `0xc25d25f1cebbca8a` | `aurelionsol_spell1_new_looptoin.anm` | `AurelionSol_Spell1_new_looptoin_anm` |
| S L608 | `Spell1_2Run` | `0x6800da4ce9730f95` | `aurelionsol_spell1_2run.anm` | `Spell1_2Run` |
| S L883 | `Spell1_2Idle` | `0xf5d8f9f3fdee745f` | `aurelionsol_spell1_2idle.anm` | `Spell1_2Idle` |
| S L2206 | `Spell4` | `0xadffe4d26bdd8071` | `aurelionsol_spell4_calamity.anm` | `Spell4` |
| S L2727 | `0xebaa1536` | `0x7e119f672dd8f7d9` | `aurelionsol_spell4_base.anm` | `AurelionSol_Spell4_base_anm` |
| S L1047 | `Spell4_2Idle` | `0x61526fdc174ad6f7` | `aurelionsol_spell4_calamity2idle.anm` | `Spell4_2Idle` |
| S L2774 | `0x37c55711` | `0xe983ed3b65095de4` | `aurelionsol_spell4_2idle.anm` | `AurelionSol_Spell4_2Idle_anm` |
| G L15 | `Attack1_BASE` | `0xb81982093db76af2` | `gnar_attack1.anm` | `Gnar_Attack1_anm` |
| G L28 | `Attack2_BASE` | `0xe62650b6c7ebc9bd` | `gnar_attack2.anm` | `Gnar_Attack2_anm` |
| G L234 | `Run1_In` | `0x77d7bfa6bf5d6789` | `gnar_run1_in.anm` | `Run1_In` |
| G L86 | `Run_Base` | `0x8c0680be1f409091` | `gnar_run1.anm` | `Run_Base` |
| G L264 | `0x5118bb68` | `0xba17ecc273af3df9` | `gnar_revert.anm` | `Gnar_Revert_anm` |
| G L766 | `Revert_Scale` | `0x9d9874d772708bc7` | `gnar_revert_scale.anm` | `Revert_Scale` |
| G L786 | `Respawn` | `0x6d5bdd5074ef2950` | `gnar_recall_return.anm` | `Respawn` |
| B L22 | `Attack1_BASE` | `0xcc41f16e1b851215` | `gnarbig_attack1.anm` | `GnarBig_Attack1_anm` |
| B L28 | `Attack2_BASE` | `0xb6e0ed231d8b4eb8` | `gnarbig_attack2.anm` | `GnarBig_Attack2_anm` |
| B L321 | `Run_In` | `0xdf72530c2a862f67` | `gnarbig_run_in.anm` | `Run_In` |
| B L169 | `Run_Base` | `0x48fdedc53417e42c` | `gnarbig_run.anm` | `Run_Base` |
| B L46 | `Rage_Stop` | `0xe2455ed829c7cda0` | `gnarbig_rage_stop.anm` | `Rage_Stop` |
| B L82 | `Rage_Scale` | `0x325bb8c07da4c1b5` | `gnarbig_rage_scale.anm` | `Rage_Scale` |
| B L133 | `0x3c537b25` | `0x44ba134309c0a954` | `gnarbig_spell2_tran.anm` | `GnarBig_Spell2_Tran_anm` |
| B L157 | `Spell2_BASE` | `0x7052edc795ce3d71` | `gnarbig_spell2.anm` | `GnarBig_Spell2_anm` |
| B L438 | `0x4de41080` | `0x30fb61ff04b7859e` | `gnarbig_turret_attack01.anm` | `GnarBig_Turret_Attack01_anm` |
| B L432 | `0x1377fdf7` | `0xc6b283548409ac38` | `gnarbig_turret_attack_fast.anm` | `GnarBig_Turret_Attack_Fast_anm` |
| B L467 | `0x294ee418` | `0x3f634255f876b460` | `gnarbig_death.anm` | `GnarBig_Death_anm` |
