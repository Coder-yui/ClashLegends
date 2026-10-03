# 实现现状与接入

[返回总览](README.md)

本页列当前代码能力与所有者，不以历史测试通过代替当前验证。规则以对应专题正文为准；单卡数值和素材见[单位手册](../units/README.md)，全卡核对范围见[覆盖记录](../reference/UNIT_DOC_COVERAGE.md)，运行方式见[测试手册](../../tests/README.md)。

## 当前支持

| 能力 | 权威入口 / 所有者 | 规则及代表对象 |
| --- | --- | --- |
| 状态实例、叠加与时钟 | StatusInstances、ControlState；Unit聚合权限 | [共通规则](CORE.md)、[硬控](HARD_CONTROL.md)；20Hz，来源独立到期，抑制不延寿 |
| 普攻及技能取消 | AttackTimeline、ActiveSkillLifecycle、CommandSchedule | [动作合同](ACTIONS.md)；取消未释放后段，保留同批已提交伤害与独立结果 |
| 自主技能位移 | DashStrikeState、OrnnChargeState | 位移中有效眩晕/击退取消；普通停止后段仍受技能保护；冰冻/凝滞取消未释放后段。[凯隐](../units/kayn.md)、[奥恩](../units/ornn.md)、[虚空女皇](../units/belveth.md) |
| 外部击退、冲撞 | KnockbackState、StructureRushState | 普通击退独立计时；[先锋](../units/rift_herald.md)仅冲撞阶段免疫双方凝滞 |
| 严格脱战 | Unit战斗事实与空闲时长；StealthState消费时长 | [公共战斗规则](CORE.md#战斗事实与严格脱战)；瑟提1秒后衰减、图奇2秒后新入隐；凝滞不累计空闲，奥恩被动不接入 |
| 凝滞与交互隔离 | Unit/Tower.apply_stasis、CombatInteraction、ControlState | [凝滞规则](SPECIAL_STATES.md#凝滞)；普通单位、建筑卡、双方防御塔有效，水晶免疫；动作取消，旧Buff计时并抑制 |
| 在途法术 | SpellSystem | [在途法术](../CARD_DESIGN.md#可配置的在途法术)；可配速、固定落点、权威抵达音画 |
| 不可推动占位下牌 | DeploymentRules、UnitLandingQuery | [部署边界](SPECIAL_STATES.md#碰撞选取与收益)；凝滞/建筑占位避让，普通与冰冻单位自然碰撞；玩家无落点等待，召唤/复生使用自身区域 |
| 强制位移与落点收尾 | Unit.apply_forced_displacement、KnockbackState、MovementSystem、UnitLandingQuery | [强制位移](HARD_CONTROL.md#通用强制位移已实现)；途中无碰撞、保速两阶段落点修正，六虫/八鱼共用；普通击退仍防穿透 |
| 来源条件保护 | CombatInteraction、TargetProtectionState | [格温](../units/gwen.md)固定圣霭；按来源判断，不是全局targetable；旧追踪失效不恢复 |
| 追踪及直线弹体 | ProjectileSystem | [弹体规则](../CARD_DESIGN.md#弹体失效与独立结果)；主目标失效即销毁追踪弹体，无主命中则无依附溅射 |
| 护盾与收益 | ShieldState、CombatResolver | [增益](BUFFS.md)；独立盾层、实际治疗后过量转盾；赛恩旧爆炸盾和黄沙旧恢复盾到期为凝滞特例 |
| 形态与致死生命周期 | Unit、DeathFormState、自然生命周期阶段 | [剑魔](../units/aatrox_ultimate.md)、[纳尔](../units/gnar_small.md)、[赛恩](../units/sion.md)、[冰鸟蛋](../units/anivia_egg.md)；形态基础属性不经普通Buff抑制 |
| 流血与血怒 | BleedState、StatusInstances、ActiveSkillRoster | [德莱厄斯](../units/darius.md)；来源独立层数及余量，凝滞跳过伤害且不补发 |
| 局内成长、穿地形 | MatchCardGrowth、TerrainTraversalState | [凯隐](../units/kayn.md)；队伍成长只改变后续部署，穿地形普攻先找合法出口 |
| 命中叠层 | StatusInstances、CombatResolver | [天使](../units/kayle.md)；真实命中加层，独立焰浪不重复加层 |
| 控制延后召唤 | Unit、CommandSchedule独立召唤队列 | [璐璐](../units/lulu.md)；受控到期保留一批，紫光发出后不依赖来源动作 |
| 一次性永久成长 | Unit、ActiveSkillEffectSystem | [永久成长](BUFFS.md#一次性永久成长)；璐璐生命/体型和奥恩永久普攻倍率在凝滞中保留 |
| 永久普攻增幅 | TeamAttackBoostSystem | [奥恩](../units/ornn.md)；独立锤子、目标预留、抵达准入；就绪/CD与短锻造动作分离，中断不退款，与公共脱战分开 |
| 模型、标识、声音 | UnitModel3D、TowerModel3D、HUD与GameAudioManager | [表现合同](PRESENTATION.md)；金身隐藏附属标识，声音按实例所有者取消；冰冻/眩晕不暂停塔/水晶生命周期动画 |
| 联网 | 权威快照、可靠表现事件及生命周期事件 | [网络协议](../reference/NETWORK_PROTOCOL.md)维护唯一版本/载荷事实；客户端不自行结算解控、伤害或收益 |

## 尚未提供完整生产链

禁锢、沉默、嘲讽、持续吸引、通用中毒、多来源隐身及Reveal仍不是可直接配置的完整能力。专题中的对应条目是设计合同；不能仅因规则或枚举存在就声称实现。现有普通击退、图奇隐身与德莱厄斯流血不等于这些通用系统。

## 部署表现边界

单段与多段部署统一保留眩晕/击退前的播放进度，冰冻/凝滞仍取消并定格，见[部署合同](ACTIONS.md#部署)。卡牌大师跨出生预部署声音已确认为独立传送结果，允许自然播完，见[声音边界](PRESENTATION.md#预部署音轨的当前边界)。

## 扩展约束

- 保持现有所有者，职责见[维护架构](../MAINTENANCE_ARCHITECTURE.md)；不另造包揽动作、盾层、轨迹的状态对象。
- 新字段必须有四域归属、实际读取方、schema/validator、回归；正式施加走准入接口，网络走显式副本接口。
- 状态开始、刷新、抑制恢复、取消和自然结束分开；取消不伪造正常完成。新增能力覆盖[验收清单](VALIDATION.md)中适用场景，不把整张清单当作已执行结果。
- 权威时钟只在主机推进。客户端只消费状态、动作身份及事件；重复、迟到消息不能恢复已取消动作。协议变更同步双方读写及校验。
- 表现资源配置、实际事件触发、目视/试听通过分开记录。性能结论须有测量，不能由抽象程度推断。

旧迁移过程仅在需要追溯时查看[历史快照](../archive/2026-09-22/status_implementation_before_cleanup.md)。

强化冰冻通过`spell_freeze`技能定义在冻结结束后创建2秒区域，移速与攻速各降低30%。SpellSystem按20Hz给圈内敌方Unit独立续期`slow`与`attack_slow`，沿用最强值聚合、动作进度重算和快照表现；防御塔受起始冻结，水晶免疫冰冻；防御塔与水晶不接受后续双减速。地面冰纹由BattlePresentation3D只读法术表现窗口，使用冰霜护手原版遮罩与人物共用深度，图标登记在visual域。

## 怒气暴击与拒绝死亡

Unit读取rage_crit_multiplier，仅支持两点资源的离散近战单位；被动资源不依赖主动槽。正式普通出手加1，暴击出手消费满层，取消前摇不消费。undying_rage由ActiveSkillEffectSystem在Cast Start即时建立StatusInstances的undying窗口并满怒，生命入口在护盾结算后将伤害钳制到1；固定Tick到期后恢复正常伤害。施放权限经Unit.can_start_active_skill逐技能判断，除凝滞外允许受控开始；普通技能权限不变。沿用现有资源/增益/攻击序号快照与empowered_reset动作取消事件，无新增网络字段。

腐蚀法术由SpellSystem持有独立固定区域，20Hz时钟每10Tick结算一次60伤害，0.5至5秒共10次；入圈减速独立于伤害节拍立即检测；强化20%移速减缓复用ControlState与通用减速表现。客户端可靠事件只创建画面/区域音频，权威血量和减速沿用快照。字段与规则见[腐蚀法术](../units/corrosion.md)。
