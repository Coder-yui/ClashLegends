# 当前卡牌文档覆盖核对

[返回单位索引](../units/README.md)

更新于2026-10-09。当前覆盖全部61项CardDB定义、65篇卡牌/形态正文及4篇系统对象正文。数量包含不可组卡的形态和召唤物，不等于可选卡池数量。

本页维护注册定义、玩法正文和素材入口之间的对应关系。修改卡牌时，对照编译定义及下列消费者核对数值、条件与时序；编队采用实际成员定义，覆盖形态采用基础与transformed_stats合并值，召唤部署采用生成入口的覆盖值。本页收录不代表本次逐卡重新运行、目视或试听通过。

## 共用规则与消费者

| 范围 | 唯一规则入口 | 实际消费者 |
| --- | --- | --- |
| 数值/伤害/收益 | [数值](../NUMERIC_SYSTEM.md)、[增益](../status/BUFFS.md) | Unit、BattleNumbers、CombatResolver、ShieldState |
| 动作/技能/位移 | [动作](../status/ACTIONS.md)、[硬控](../status/HARD_CONTROL.md) | AttackTimeline、ActiveSkillLifecycle/EffectSystem、DashStrikeState、OrnnChargeState、KnockbackState |
| 战斗事实/脱战 | [公共规则](../status/CORE.md#战斗事实与严格脱战) | Unit、StealthState；奥恩独立TeamAttackBoostSystem |
| 交互/凝滞/选取 | [特殊状态](../status/SPECIAL_STATES.md) | CombatInteraction、ControlState、StatusInstances、DeploymentRules |
| 弹体/法术 | [弹体](../CARD_DESIGN.md#弹体失效与独立结果)、[凝滞卡](../units/stasis.md) | ProjectileSystem、SpellSystem、CommandSchedule |
| 模型/标识/音频 | [表现](../status/PRESENTATION.md)、[音频缺项](../AUDIO_CARD_MAP.md) | UnitModel3D、TowerModel3D、PresentationConfig、GameAudioManager |
| 成长/形态/召唤 | [机制](../CARD_DESIGN.md)及单卡 | MatchCardGrowth、TerrainTraversalState、DeathFormState、Unit、CommandSchedule |

编队读取成员定义；四类兵音频在阵营覆盖中，不以顶层events为空判成缺声音。镜像复用被复制对象。形态读取基础与覆盖合成结果。法术无角色骨骼；不为它伪造模型/动作验收。`sustain`不保证循环；声音素材已配置不保证每个场景实际触发或用户已认可听感。

## 逐项覆盖（63篇正文）

玩法正文保留中文数值和单卡规则，素材页记录动作/声音映射；公共规则在对应专题维护。静态审计检查本表与注册定义、形态例外的一致性，语义核对和运行验证按受影响范围执行。

| 定义 / 正文（含形态） | 当前机制与边界重点 | 动画 / 音频 |
| --- | --- | --- |
| `nocturne` · [永恒梦魇](../units/nocturne.md) | 3费空中近战、五击范围追加、完整敌方效果抵挡 | [动作](../units/animations/nocturne.md) · [声音](../units/audio/nocturne.md) · [特效](../units/effects/nocturne.md) |
| `jinx` · [金克丝](../units/jinx.md) | 5费火箭炮、45范围空地溅射、3秒建筑助攻、2秒衰减加速 | [动作](../units/animations/jinx.md) · [声音](../units/audio/jinx.md) |
| `jinx`覆盖形态 · [轻机枪](../units/jinx_minigun.md) | 170射程、1秒间隔、三层命中攻速、切枪清层重置后摇 | 复用金克丝入口 |
| `aatrox` · [剑魔](../units/aatrox.md) | 四段被动/吸血；大灭基础生命保留、到期截上限 | [动作](../units/animations/aatrox.md) · [声音](../units/audio/aatrox.md) |
| `aatrox`覆盖形态 · [剑魔·大灭](../units/aatrox_ultimate.md) | 1350上限、转换1秒后寿命5秒；被动段/吸血、击杀刷新及到期落点 | 复用剑魔入口 |
| `anivia` · [冰鸟（艾尼维亚）](../units/anivia.md) | 一次死亡变蛋；固定冰暴与减速区域 | [动作](../units/animations/anivia.md) · [声音](../units/audio/anivia.md) |
| `anivia_egg` · [冰鸟的蛋](../units/anivia_egg.md) | 3秒孵化新实体；旧控制不继承 | [动作](../units/animations/anivia_egg.md) · [声音](../units/audio/anivia_egg.md) |
| `apex_turret` · [尖端炮台](../units/apex_turret.md) | 45秒衰血；主命中溅射与独立穿透激光 | [动作](../units/animations/apex_turret.md) · [声音](../units/audio/apex_turret.md) |
| `ashe` · [艾希](../units/ashe.md) | 8箭扇形、每施法去重与减速 | [动作](../units/animations/ashe.md) · [声音](../units/audio/ashe.md) |
| `aurelionsol` · [龙王](../units/aurelionsol.md) | 持续吐息免致盲；星辰创建即独立 | [动作](../units/animations/aurelionsol.md) · [声音](../units/audio/aurelionsol.md) |
| `belveth` · [虚空女皇](../units/belveth.md) | 空军攻城；空中突进受控取消、死亡8鱼 | [动作](../units/animations/belveth.md) · [声音](../units/audio/belveth.md) |
| `corki` · [库奇](../units/corki.md) | 三枚导弹首碰爆炸、第三枚1.8倍；空地溅射不重复直接命中 | [动作](../units/animations/corki.md) · [声音](../units/audio/corki.md) |
| `explosive_cask` · [爆破酒桶](../units/explosive_cask.md) | 3费径向爆炸、180伤害、击退40；强化270 | [动画](../units/animations/explosive_cask.md) · [声音](../units/audio/explosive_cask.md) · [特效](../units/effects/explosive_cask.md) |
| `corrosion` · [腐蚀法术](../units/corrosion.md) | 5秒10次伤害；塔/水晶30%、强化减速20% | [无模型/特效](../units/effects/corrosion.md) · [声音](../units/audio/corrosion.md) |
| `darius` · [德莱厄斯](../units/darius.md) | 来源流血/血怒；劈砍与免费追斩 | [动作](../units/animations/darius.md) · [声音](../units/audio/darius.md) |
| `freeze` · [冰冻](../units/freeze.md) | 3秒敌方冰冻；强化后2秒减速区 | [动作](../units/animations/freeze.md) · [声音](../units/audio/freeze.md) |
| `garen` · [盖伦](../units/garen.md) | 攻城、强化待发；旋转非自主位移技能 | [动作](../units/animations/garen.md) · [声音](../units/audio/garen.md) |
| `gnar` · [小纳尔](../units/gnar_small.md) | 双形态命中阈值；生命差额/截断、冻结待变形 | [动作](../units/animations/gnar_small.md) · [声音](../units/audio/gnar_small.md) |
| `gnar`覆盖形态 · [大纳尔](../units/gnar_mega.md) | 820生命、4次真实命中、1.33秒变小锁及生命截断 | 复用纳尔入口 |
| `gwen` · [格温](../units/gwen.md) | 中心/多段剪切；来源条件圣霭 | [动作](../units/animations/gwen.md) · [声音](../units/audio/gwen.md) |
| `heal` · [治疗术](../units/heal.md) | 200基础；强化300、过量转盾逐目标准入 | [动作](../units/animations/heal.md) · [声音](../units/audio/heal.md) |
| `heavy_minion_squad` · [重装部队](../units/heavy_minion_squad.md) | 超级兵+炮车；成员独立Buff、共享技能资格 | [动作](../units/animations/super_minion.md) · [声音](../units/audio/heavy_minion_squad.md) |
| `imp` · [雾行者](../units/imp.md) | 墓碑生成；无主动、普通近战 | [动作](../units/animations/imp.md) · [声音](../units/audio/imp.md) |
| `kayle` · [正义天使（近战）](../units/kayle.md) | 按付款金币选形态；真实命中攻速、W自疗 | [动作](../units/animations/kayle.md) · [声音](../units/audio/kayle.md) |
| `kayle_ranged` · [正义天使（远程）](../units/kayle_ranged.md) | 105追踪光剑+55独立扩宽焰浪；被动/W共用 | [动作](../units/animations/kayle.md) · [声音](../units/audio/kayle.md) |
| `kayn` · [凯隐](../units/kayn.md) | 共享成长只影响后续部署；穿地形出口与Q分段 | [动作](../units/animations/kayn.md) · [声音](../units/audio/kayn.md) |
| `kayn_assassin` · [影流刺客](../units/kayn_assassin.md) | 远程命中成长；入地形120回复/加速、Q1费 | [动作](../units/animations/kayn.md) · [声音](../units/audio/kayn.md) |
| `kayn_slayer` · [拉亚斯特](../units/kayn_slayer.md) | 近战命中成长；生命比例附伤/回血、Q2费 | [动作](../units/animations/kayn.md) · [声音](../units/audio/kayn.md) |
| `lightning` · [大型电击法术](../units/lightning.md) | 最高当前生命逐段重选、3次不重复、递增强化 | [动作](../units/animations/lightning.md) · [声音](../units/audio/lightning.md) |
| `lulu` · [璐璐](../units/lulu.md) | 受控召唤待发；已发紫光独立、永久成长 | [动作](../units/animations/lulu.md) · [声音](../units/audio/lulu.md) |
| `masteryi` · [剑圣](../units/masteryi.md) | 第三招追加刀；高原血统与减速抑制 | [动作](../units/animations/masteryi.md) · [声音](../units/audio/masteryi.md) |
| `melee_minion` · [近战兵](../units/melee_minion.md) | 近战；4秒男爵移速/伤害 | [动作](../units/animations/melee_minion.md) · [声音](../units/audio/melee_minion.md) |
| `melee_minion_squad` · [近战兵小队](../units/melee_minion_squad.md) | 4近战编队；资格转交、成员Buff | [动作](../units/animations/melee_minion.md) · [声音](../units/audio/melee_minion_squad.md) |
| `minion_squad` · [小兵分队](../units/minion_squad.md) | 3近战+3远程；混合成员各取对应Buff | [动作](../units/animations/melee_minion.md) · [声音](../units/audio/minion_squad.md) |
| `mirror` · [镜像法术](../units/mirror.md) | 历史付款形态、复制技能槽；无独立战斗模型 | [动作](../units/animations/mirror.md) · [声音](../units/audio/mirror.md) |
| `missfortune` · [赏金猎人](../units/missfortune.md) | 逐目标首击；3秒移速/攻速Buff | [动作](../units/animations/missfortune.md) · [声音](../units/audio/missfortune.md) |
| `ornn` · [奥恩](../units/ornn.md) | 独立锻造及永久普攻倍率；分阶段冲锋 | [动作](../units/animations/ornn.md) · [声音](../units/audio/ornn.md) |
| `pantheon` · [潘森](../units/pantheon.md) | 预部署扫掠；红怒资源及短Q | [动作](../units/animations/pantheon.md) · [声音](../units/audio/pantheon.md) |
| `pix` · [皮克斯](../units/pix.md) | 5飞行成员；命中吸血及溢出生命 | [动作](../units/animations/pix.md) · [声音](../units/audio/pix.md) |
| `ranged_minion` · [远程兵](../units/ranged_minion.md) | 远程弹体；5秒男爵攻速/伤害 | [动作](../units/animations/ranged_minion.md) · [声音](../units/audio/ranged_minion.md) |
| `ranged_minion_squad` · [远程兵小队](../units/ranged_minion_squad.md) | 3远程编队；资格转交、成员Buff | [动作](../units/animations/ranged_minion.md) · [声音](../units/audio/ranged_minion_squad.md) |
| `rift_herald` · [峡谷先锋](../units/rift_herald.md) | 准备锁定目标；新增建筑在冲撞中接触挡停；冲撞双方凝滞免疫、6蠕虫 | [动作](../units/animations/rift_herald.md) · [声音](../units/audio/rift_herald.md) |
| `sett` · [腕豪](../units/sett.md) | 双拳/豪意；严格脱战衰减、起手盾与伤害节点 | [动作](../units/animations/sett.md) · [声音](../units/audio/sett.md) |
| `shurima_guard` · [恕瑞玛卫队](../units/shurima_guard.md) | 6士兵；未破旧盾2秒到期回满含凝滞特例 | [动作](../units/animations/shurima_guard.md) · [声音](../units/audio/shurima_guard.md) |
| `siege_minion` · [炮车兵](../units/siege_minion.md) | 远程炮弹；5秒150%男爵增伤 | [动作](../units/animations/siege_minion.md) · [声音](../units/audio/siege_minion.md) |
| `siege_minion_squad` · [炮车部队](../units/siege_minion_squad.md) | 3炮车编队；资格转交、成员Buff | [动作](../units/animations/siege_minion.md) · [声音](../units/audio/siege_minion_squad.md) |
| `sion` · [赛恩](../units/sion.md) | 致死等待2秒、狂暴衰血；旧盾凝滞到期爆炸 | [动作](../units/animations/sion.md) · [声音](../units/audio/sion.md) |
| `sion`覆盖形态 · [狂暴赛恩](../units/sion_berserk.md) | 2400生命、480/秒自然衰血、50%实际掉血吸血及禁主动 | 复用赛恩入口 |
| `stasis` · [凝滞法术](../units/stasis.md) | 水晶出发在途、抵达范围；双方塔有效/水晶免疫 | [无模型/特效](../units/effects/stasis.md) · [声音](../units/audio/stasis.md) |
| `sun_disc` · [太阳圆盘](../units/sun_disc.md) | 普通地面/精确塔墟；寿命差异、范围护盾 | [动作](../units/animations/sun_disc.md) · [声音](../units/audio/sun_disc.md) |
| `super_minion` · [超级兵](../units/super_minion.md) | 近战；男爵移速/伤害/独立盾 | [动作](../units/animations/super_minion.md) · [声音](../units/audio/super_minion.md) |
| `super_minion_squad` · [攻城部队](../units/super_minion_squad.md) | 2超级兵编队；资格转交、成员Buff | [动作](../units/animations/super_minion.md) · [声音](../units/audio/super_minion_squad.md) |
| `target_dummy` · [训练木桩（建筑卡）](../units/target_dummy.md) | 15秒衰血、不可普攻；余震减伤及到期爆炸，与工作台木桩独立 | [动作](../units/animations/target_dummy.md) · [声音](../units/audio/target_dummy.md) |
| `teemo` · [提莫](../units/teemo.md) | 强化致盲两次；无持续毒伤 | [动作](../units/animations/teemo.md) · [声音](../units/audio/teemo.md) |
| `tombstone` · [墓碑](../units/tombstone.md) | 20秒寿命；受控最多保留一批、被击杀或自然死亡额外召唤两只 | [动作](../units/animations/tombstone.md) · [声音](../units/audio/tombstone.md) |
| `twisted_fate` · [卡牌大师](../units/twisted_fate.md) | 全图合法地面部署；第五击、三牌去重穿透 | [动作](../units/animations/twisted_fate.md) · [声音](../units/audio/twisted_fate.md) |
| `tristana` · [麦林炮手](../units/tristana.md) | 远程对空；5秒攻速增益 | [动作](../units/animations/tristana.md) · [声音](../units/audio/tristana.md) |
| `tryndamere` · [蛮族之王](../units/tryndamere.md) | 独立怒气、受控释放与4秒保命 | [动作](../units/animations/tryndamere.md) · [声音](../units/audio/tryndamere.md) |
| `twitch` · [图奇](../units/twitch.md) | 公开玩家视图；严格脱战入隐、攻击起手破隐、穿透箭 | [动作](../units/animations/twitch.md) · [声音](../units/audio/twitch.md) |
| `voidfish` · [虚空鱼](../units/voidfish.md) | 虚空女皇衍生；空地近战、无主动 | [动作](../units/animations/voidfish.md) · [声音](../units/audio/voidfish.md) |
| `voidmite` · [虚空蠕虫](../units/voidmite.md) | 先锋衍生；外抛部署、仅攻城、无主动 | [动作](../units/animations/voidmite.md) · [声音](../units/audio/voidmite.md) |
| `xin` · [赵信](../units/xin.md) | 部署横扫/击退；三击回血、主动范围击退 | [动作](../units/animations/xin.md) · [声音](../units/audio/xin.md) |
| `zap` · [电击法术](../units/zap.md) | 固定范围55伤害/眩晕；强化独立第二击 | [动作](../units/animations/zap.md) · [声音](../units/audio/zap.md) |

## 系统对象

| 对象 | 核对范围 |
| --- | --- |
| [防御塔](../units/princess_tower.md) | Tower攻击与生命/碎块生命周期分开；冰冻/眩晕不暂停碎块；凝滞有效 |
| [水晶](../units/nexus.md) | 无攻击；升起/运转/爆炸不被冰冻/眩晕暂停；凝滞免疫 |
| [竞技场](../units/arena.md) | 场地尺寸、双方坐标、比赛/经济/兵线时钟及地图/全局音频入口 |
| [训练木桩](../units/training_dummy.md) | 工作台对象，非卡池；生命/碰撞数值及无自主攻击 |

场地防御塔/水晶使用Tower；墓碑、太阳圆盘、尖端炮台、训练木桩建筑卡使用Unit，不能把Tower生命周期动画规则无条件复制给建筑卡。

## 维护与验证边界

变更实现时同步单卡正文、相关公共规则和产品详情文案。例如炮台270像素为6.75格，远程天使使用追踪光剑加独立焰浪，图奇入隐受严格脱战约束，太阳圆盘允许普通合法地面及精确塔墟部署。这些事实在定义与正文中分别服务产品显示和完整玩法说明。

[静态审计](../../tools/maintenance/README.md)检查注册、覆盖表、链接与资源引用；数值标记自动核对首批赛恩、凯隐、潘森的显式字段。其余中文数值、技能语义、形态与召唤覆盖仍须按消费者核对，不能把审计通过当作全文自动证明。

机制回归、联网与实际渲染/试听的范围和命令见[测试手册](../../tests/README.md)。素材配置、实际触发、主观验收分别记录；历史通过次数只证明当时工作区。尚未实现的通用能力以[实现现状](../status/IMPLEMENTATION.md)为准。

爆破酒桶：见[玩法](../units/explosive_cask.md)、[动画](../units/animations/explosive_cask.md)、[音频](../units/audio/explosive_cask.md)及[特效](../units/effects/explosive_cask.md)。

| `azir` [沙漠皇帝](../units/azir.md) | [动画](../units/animations/azir.md) | [音频](../units/audio/azir.md) |
| `sand_soldier` [黄沙士兵](../units/sand_soldier.md) | [动画](../units/animations/sand_soldier.md) | [音频](../units/audio/sand_soldier.md) |
