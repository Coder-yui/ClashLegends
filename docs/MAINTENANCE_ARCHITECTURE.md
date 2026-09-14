# 项目结构与维护边界

本页说明状态由谁持有、改动应落在哪里。共同规则见 [AGENTS](../AGENTS.md)，测试命令见 [测试手册](../tests/README.md)。

## 模块职责

| 模块 | 负责内容 |
| --- | --- |
| CardDB、逐卡定义、CardDefinitionCompiler、CardShapeValidator、schema/validator | 原始域契约、类型前置检查、只读内容与字段语义校验 |
| Main | 比赛生命周期、模块装配、请求资格、费用与每步编排 |
| FixedStepClock | 固定 20Hz 时钟与积压；Main 每帧最多赶 4 Tick，或已耗时 8 ms 后停止继续赶步，剩余积压完整保留，单 Tick 不截断 |
| MatchRules / CommandSchedule | 比赛规则；卡牌与技能排程 |
| Unit、ControlState、AttackTimeline、ShieldState | 通用单位、控制聚合、普攻状态和独立护盾层 |
| MovementSystem、ArenaRules、路径搜索 | 移动、部署几何、局部避让、碰撞与寻路 |
| CombatResolver / ProjectileSystem | 真实命中、弹体与命中收益 |
| SpellSystem / ActiveSkillEffectSystem | 法术与技能区域及各自集合 |
| UnitPresentationState / PresentationConfig / PresentationEvents | 只读状态、统一形态选择、真实事件能力 |
| UnitModel3D、TowerModel3D、BattleEffects2D、GameAudioManager | 模型、效果和声音 |
| CardDetails / CardArt / MatchResources | UI 文案、卡面发现与本局资源保留 |

数据流：请求 → Main 校验 → 命令排程 → 固定模拟与结算 → 比赛状态/快照/表现事件 → UI、模型与声音。

Unit/Tower 通过 BattleContext 使用战场服务，不探测 `current_scene` 寻找 Main。区域集合留在对应系统，禁止重新给 Main 增加私有数组别名。

## 改动应落在哪里

- **普通新卡：**定义、注册、素材和文档。不要加入英雄名分支。
- **新战斗规则：**对应领域系统、字段校验与测试；需要客户端显示时同步快照或事件。
- **新表现：**只读当前状态或真实事件；确实缺事件入口时先补派发、消费与去重。
- **工作台：**UI 在 `scripts/ui/development_workbench.gd`，模型预览和场景配方在 `scripts/ui/workbench/`；仍复用正式出牌/技能接口。

## 需要保留的语义

控制采用最长时间、最强倍率聚合，不按来源相乘；主动增益保留最长窗口、最高倍率和免疫合并。按来源独立撤销属于新机制。

在途弹体保存出手时来源与形态，来源死亡后仍可命中，但不给死者回血或技能资源。音频与模型不驱动伤害、移动或联网状态。

快照版本与固定载荷必须同时维护读写端；当前版本 19，单位载荷 40 项（含出生描述与部署剩余时间），顶层含会话标识与生命周期序号，修改协议需提升版本。晚到表现按进度对齐，重复序号不重播。NetworkEntityLifecycle 拥有出生描述、销毁标记和快照屏障；同 Tick 由生命周期序号区分，快照可以恢复未知实体，旧局生成/销毁/快照不能污染新局。

## 维护与已知限制

核心测试由 `tests/mechanics_check.gd` 和 `tests/suite_catalog.json` 统一编排；每套件重建并释放自己的场景，支持选跑与反序，检查战斗对象和根节点无遗留。维护审计检查资源、链接、注册和孤立 UID，不能替代运行回归。

离线加工放 `tools/`，已退役素材放受 Godot 忽略的 `assets/archive/`，已结束研究放 `docs/archive/`。不因内容相同就合并不同音频事件，不能删除模型外部纹理或可编辑源件。

目前仍有 Main 与领域系统的耦合；资源预留也不消除实例化成本。性能和设备验证的缺口见 [开发状态](DEV_PLAN.md)，历史测量见 [结构验收](archive/2026-09-11/maintenance_validation.md)。

终局由 MatchRules 返回胜者阵营与结束原因；Main 通过可靠 RPC 发送包含最终快照的终态信封。客户端先应用最终状态，再按本地阵营显示结果；相同终态幂等，之后普通快照与实体事件不能恢复战斗。终局清空命令、弹体、区域效果与战斗音频；返回菜单时释放本场 ENet 连接。

MatchSession 持有大厅/加载/运行/结束/断线阶段、唯一对手与命令序号。双方先确认协议版本、卡牌内容指纹及完整合法卡组，再分别加载战场并确认就绪；加载期间不推进权威 Tick。运行时部署/技能只接受绑定对手控制队伍 1 的当前会话请求，并按单调序号去重。卡组不能局中重注册；所有表现事件携带会话标识。规则算法或 RPC 协议变更必须提升 `MatchSession.PROTOCOL_VERSION`；卡牌内容变化自动改变指纹。加载超时 30 秒停止，断线通过统一终局入口清理并允许返回菜单；不提供局内续接。

护盾由 ShieldState 独立拥有每层时间、生命、容量与衰减余量；Unit/Tower 仅委托添加、推进与吸收并提供总量只读视图。客户端塔快照使用独立表现值，不构造权威护盾层。主动命令的付款收据由 CommandPayment 持有原付款者弱引用及实际金额，CommandSchedule 统一作一次性结算：开始施放消费、存活取消退款、死亡/会话清场关闭收据。

CommandSchedule 持有等待部署的命令，不预留建筑占地。Main 在卡牌建筑真正生成前共用完整部署合法性校验，冲突时确定性寻找最近合法格；全场无位置时保留到下一 Tick。生成后才加入结构与导航，太阳圆盘重建状态由最终落点决定。

音频区域时长只由 GameAudioManager._process 推进。工作台通过 set_battle_paused 请求暂停/恢复，音频管理器保存原有控制暂停状态；技能效果系统不再推进或清理声音。工作台清场分别调用命令、弹体、法术、技能效果和音频所有者的公开生命周期入口。

ControlState 拥有硬控倒计时与副本状态替换；Unit 仍决定部署/行为阶段何时消耗本 Tick，Tower 通过同一对象读取冻结并保留原秒数精度。网络适配调用副本入口，不直接改写控制计时器。VisualActionSequence 只持有动作片段、裁剪区间、目标时长与游标，不引用实体、场景或播放器；UnitModel3D 保留动作优先级仲裁、控制覆盖及实际播放/材质处理。换模型、动作结束与死亡统一清理序列。

AttackTimeline 拥有攻击间隔、前摇、后摇与基础攻速表现时间的全部生产写入。Unit 在原阶段顺序调用推进、开始、命中提交、取消和重置接口；普通取消保留已提交的攻击间隔，施法/变形显式重置。命中与后摇设置仍分开，避免触发变形后再写回旧形态后摇。ModelVisualResources 管理模型动画库深副本与原始/Buff/受击/冻结材质，重新绑定和退场恢复原始覆盖并释放引用。UnitModel3D 拥有模型节点与动作仲裁/实际播放，VisualActionSequence 拥有动作序列进度，资源对象不读取战斗实体。

ProjectileSystem 独占客户端弹体目标与插值位置，快照写入和外部读取均不暴露内部字典别名；网络适配显式注入该系统，跨局统一清除客户端弹体。Main 拥有实体和技能注册索引及元数据组合，MatchRules 拥有计时/结束状态，Tower 拥有副本到死亡表现与导航释放的转换。网络只解码并请求相应入口，RPC 保留在 Node。
