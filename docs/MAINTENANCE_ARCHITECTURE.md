# 项目结构与维护边界

本页维护状态所有者和扩展入口。共同边界见 [AGENTS](../AGENTS.md)，代码目录见 [scripts 导航](../scripts/README.md)，验证方式见 [测试手册](../tests/README.md)。

## 模块职责

请求 → Main 校验与付款 → CommandSchedule → 固定模拟与批次结算 → 快照/表现事件 → UI、模型与声音。

| 层 | 状态所有者与职责 |
| --- | --- |
| 定义 | CardDB 注册逐卡四域；CardDefinitionCompiler 合并，CardShapeValidator 前置类型检查，CardValidator 校验语义与资源；共享定义递归只读 |
| 编排 | Main 装配节点、比赛生命周期、UI/RPC、固定阶段调用；Unit/Tower 通过 BattleContext 使用服务，不能反向探测 current_scene |
| 比赛 | FixedStepClock 积压与 Tick；MatchRules 时间/胜负；MatchSession 对手/握手/命令序号；ElixirManager 金币；MinionWaveSchedule 兵线阶段、延迟条目与有序生成请求 |
| 卡牌命令 | CardCycle 手牌与轮换；CardPlayHistory 最近成功出牌/镜像代次；MatchCardGrowth 每阵营局内成长；CommandSchedule 排程（含不依附来源的在途召唤），CommandPayment 一次性付款收据 |
| 部署 | UnitSpawnRequest 具名生成参数（不改变网络载荷）；DeploymentRules 区域/建筑合法落点；PreDeploymentSweep 预部署轨迹与扫掠查询；部署命中集合随排程条目存活 |
| 通用实体 | Unit/Tower 汇合权限、委托状态并执行生命周期；普通新卡复用 Unit，不建立英雄子类 |
| 控制与攻击 | StatusInstances 来源独立窗口；ControlState 硬控/减速；AttackTimeline 前后摇、间隔、基础攻速表现时间 |
| 生命状态 | ShieldState 每层生命/时间/衰减/恢复与爆炸资格；BleedState 来源叠层/窗口/余量；DeathFormState 致死换形资格、等待 Tick 与衰血 |
| 位移 | MovementSystem 碰撞与移动；NavGrid/BattlePathSearch 全局导航；KnockbackState 普通击退；StructureRushState 建筑冲撞；TerrainTraversalState 穿地形门禁；UnitLandingQuery 连续几何落点 |
| 命中与技能 | CombatInteraction/TargetProtectionState 准入与固定圣霭；CombatResolver 阶段命中/附带效果/收益/死亡队列；ProjectileSystem 弹体；SpellSystem 法术与可选速度配置的在途时钟；ActiveSkillEffectSystem 技能效果与 DashStrikeState、OrnnChargeState |
| 周期队伍普攻增幅 | TeamAttackBoostSystem 主机固定 Tick 选择未增幅友军并写入 Unit 永久倍率；快照只复制倍率，不复制周期时钟 |
| 主动资格 | ActiveSkillLifecycle 协调准备、起手、动作和排程，CommandSchedule 按身份结束/取消；ActiveSkillRoster 技能槽、编队转交、次数、冷却、免费追斩；效果执行身份归 CommandSchedule 与 Unit.active_skill_cast_serial |
| 联网 | NetworkEntityLifecycle 出生/销毁/快照屏障；NetworkSnapshotSystem 编解码与状态投影；RPC 保留在 Main 节点 |
| 表现 | UnitPresentationState 只读视图；PresentationConfig 形态选择；PresentationEvents 真实事件能力；UnitModel3D/TowerModel3D/BattleEffects2D 只读驱动图像；SkillEffectPresentation 拥有范围/护盾视觉实例、渲染计时与网络去重；GrowthEffect2D绘制成长气浪/叶片，GrowthMark3D以共享网格和深度测试表现持续花叶纹样 |
| 动画与资源 | VisualActionSequence 片段进度；ModelVisualResources 实例动画库与材质；MatchResources 本局资源强引用；MatchModelPool 预热/领取/回收 |
| 音频 | GameAudioManager 事件消费、播放器、区域时钟、暂停与清场；不由技能系统推进音频 |
| UI 与工作台 | CardDetails/CardArt 详情与卡面；WorkbenchSession 选择和操作会话；模型预览、声音目录、牌库及窗口布局各有独立组件 |

## 改动应落在哪里

- 普通新卡：逐卡定义、注册、正式素材和单位文档。新增字段必须有读取方、schema/validator 与回归。
- 新规则：扩展对应所有者；跨客户端可见的状态同步更新协议读写。不要在 Main 增加领域系统私有数组的别名。
- 新表现：读取状态或真实事件；缺事件时补派发、消费、去重，不能从动画回调结算伤害。
- 工作台：`scripts/ui/development_workbench.gd` 负责界面，`ui/workbench/` 提供组件；玩家、AI、RPC、工作台出牌统一走 `play_card()`。
- 离线加工与复现：放 `tools/`。正式资源只进 `assets/`，候选和验证产物留本地开发素材库。

## 需要保留的语义

主机/单机固定 20Hz；每帧最多赶 4 Tick，或已耗时 8 ms 后停止继续赶步，积压保留，单 Tick 不截断。客户端只请求操作、接收快照及事件，不自行解除控制、判伤害或提前换形。

同源状态刷新/替换、异源独立到期、强度聚合见[状态共通合同](status/CORE.md)；动作取消与权限见[动作合同](status/ACTIONS.md)。状态正时长向上取整到 Tick。AttackTimeline 的取消、命中与后摇写入分开，避免形态变化后写回旧阶段。

CombatResolver 按阶段收集并统一提交；单位行动阶段先固定 combatants 参与者名单，再推进建筑自然生命周期；自然退出生成的对象不回头加入本阶段名单。普通击退按出生身份、来源事件序号及子序号排序，不以遍历顺序分配身份。真实在途弹体保留出手来源和形态；来源死亡后仍可命中，但不给死者生命或技能资源收益。规则细节见[卡牌机制](CARD_DESIGN.md)、[数值](NUMERIC_SYSTEM.md)和[移动接触](BATTLE_CONTACT_MODEL.md)。

## 比赛与网络生命周期

MatchSession 绑定唯一对手，双方校验协议版本、内容指纹和合法卡组，再分别加载并确认就绪。加载不推进战斗；准备和等待共享 30 秒超时，局中不能重注册卡组。请求按会话/阵营/单调序号校验，所有表现事件携带会话身份。

NetworkEntityLifecycle 按生命周期序号区分同 Tick 生成与销毁；快照能恢复未知实体，旧会话不能污染新局。ProjectileSystem 独占客户端弹体目标与插值位置，外部只取副本；Main 持有网络实体索引。

终局可靠信封包含最终快照；客户端先应用状态再显示结果，重复终态幂等，普通快照不能恢复战斗。终局清命令、弹体、区域及常规战斗音频，水晶爆炸独占音轨自然结束后触发本地结果播报；返回菜单释放本场 ENet。规则或载荷变更须提升协议版本，精确契约唯一入口为[网络协议](reference/NETWORK_PROTOCOL.md)。不支持局内断线续接。

## 状态与排程所有权

CommandSchedule 通过 enqueue/take/cancel/clear 管理内部集合；inspect 仅用于低频检查，生产 Tick 不复制全量集合。付款收据绑定原付款者：开始施放消费、存活取消退款、死亡/会话清场关闭。等待部署不预留建筑占地；真正生成时选择最近合法位置，全场无位置则保留到下一 Tick。凝滞等不可推动占位的玩家部署复用这一策略，编队先整体规划；可推动单位含冰冻继续自然碰撞。召唤/复生使用全场几何，不套用玩家部署范围。

ActiveSkillRoster.entry 是单项只读视图，权威消费走 consume，客户端走 replace_replica。多单位卡的来源卡、部署身份与技能槽分别保存；转交只查询同次部署的存活成员，不能以卡 ID 相同推断资格。CardCycle 只维护牌序，可靠确认后更新客户端镜像。

盾层自然到期由 ShieldState 返回一次性结果；死亡和清除不能触发恢复或爆炸。爆炸递交技能效果批次；流血由 Unit/Tower 各自持有，CombatResolver 发放存活来源收益。形态、生命上限、待变形代次和技能资源由 Unit 汇合，死亡替身/复生的新实体不能与原位换形混用。

技能后段绑定施法身份；冰冻/死亡取消依附动作，龙王星辰等独立结果持有固定落点和归因。DashStrikeState 在 skill_effects 阶段推进可受伤的穿单位突进，OrnnChargeState 按固定速度采样地形/建筑并结算沿途命中与停点范围效果，MovementSystem 跳过这两种状态的普通推挤。状态对象不直接写 Unit 的位置、锁、寻路或形态字段；Unit 的位置转换、突进完成和致死换形接口统一应用，旧施法序号不能释放新施法。PreDeploymentSweep 只在权威端得到伤害目标；客户端采样轨迹只用于显示。

### 公共战斗事实

Unit持有唯一 `combat_idle_seconds`，旧状态推进前采样持续战斗条件。成功伤害及控制/减益入口通过CombatInteraction记录双方事实，CombatResolver保留批次来源；StealthState只消费同一空闲时长，不独立推进生产计时。瑟提资源衰减使用相同时长与自身阈值。主动位移控制取消沿用动作序号/累计取消屏障，不改变同批伤害或独立结果合同。奥恩被动系统不接入公共脱战门禁。

## 资源准备与表现复用

加载页至少保持 1 秒且等待实际准备完成。MatchResources 递归收集双方卡组、召唤物/形态、四类兵线、地图、塔、水晶与声音；资源缺失或加载失败停止准备。CardDB 启动校验路径和配置，开发验证继续执行完整资源/音频类型/特效检查。

MatchModelPool 在遮罩后预建模型和实例独立动画库。离树只读样本不参与战斗或发声；Compatibility 渲染器实际绘制不同网格/材质组合，隐藏保留样本与绘制资源。预热覆盖完整动画及受击/冻结/强化六种材质组合；相同需求合并，互斥形态容量不覆盖预热配置。

模型池只回收已审计模型/显式支持 reset_pool_visual 的包装，重置骨骼、网格、变换、动画循环区间及材质。每路径最多 64 个闲置模型，按编队、召唤与兵线预算；不足时立即创建，不阻塞模拟。UnitModel3D 代理、信号与附属特效不复用。换模型/退场恢复覆盖材质并释放引用。

### 同模型原位换形

包装同时提供 can_reuse_visual(scene_path) 与 set_visual_form(form_index) 且接受目标场景时，保留模型、骨骼、AnimationPlayer 和实例资源，只重置动作调度、更新映射并从原姿势混合。首次装配记录根高度，避免攻击补高污染换形基准；其他单位仍走换模型路径。

## 扩展接口

WorkbenchSession 只注入放置、选中、清场、重建、暂停及视图更新端口；Main 保留节点生命周期与正式操作入口。模型/声音页只读正式配置，候选使用通用离线展台。工作台不承担验收持久化或报告导出。

治疗、控制、护盾与位移分别走准入入口；新选取和已释放命中分别判断，纯控制不能依赖实际扣血。强制位移复用唯一外力状态、稳定提交顺序与通用落点查询；途中无碰撞仅由其状态开启，不放开普通击退。未支持的禁锢等不得因相邻机制存在而声称完成，见[实现现状](status/IMPLEMENTATION.md)。

## 维护与已知限制

自动测试按 contracts/combat/deployment/status/presentation/ui/network/cards 分类；目录内测试由唯一注册表编排，共享夹具不注册。全卡内容检查、共通机制与逐卡差异各有覆盖所有者，具体约定见[测试手册](../tests/README.md)。

Main、Unit、UnitModel3D 仍是较大的编排类；后续拆分应以单一状态所有者和明确生命周期为边界，不按行数机械切割，也不通过更多转发层掩盖耦合。已按边界收拢兵线、施法协调与生成请求；部署几何和场景装配仍留在 Main，后续按实际扩展需要维护。

设备、性能和联网未验证范围见[开发状态](DEV_PLAN.md)。历次记录见[归档](archive/README.md)，日常任务从[任务导航](AGENT_WORKFLOW.md)进入当前专题。
