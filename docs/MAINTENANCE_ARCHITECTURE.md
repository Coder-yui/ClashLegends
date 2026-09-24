# 项目结构与维护边界

本页说明状态由谁持有、改动应落在哪里。共同规则见 [AGENTS](../AGENTS.md)，测试命令见 [测试手册](../tests/README.md)。

## 模块职责

| 模块 | 负责内容 |
| --- | --- |
| CardDB、逐卡定义、CardDefinitionCompiler、CardShapeValidator、schema/validator | 原始域契约、类型前置检查、只读内容与字段语义校验 |
| Main | 比赛生命周期、模块装配、费用、UI/RPC 与每步编排 |
| FixedStepClock | 固定 20Hz 时钟与积压；Main 每帧最多赶 4 Tick，或已耗时 8 ms 后停止继续赶步，剩余积压完整保留，单 Tick 不截断 |
| MatchRules / CommandSchedule | 比赛规则；排程内部集合、入队/去重、取消、到期取出和收据结算 |
| ActiveSkillRoster / CardCycle | 技能槽替换、资格、编队转交、次数/冷却；手牌初始顺序和轮换 |
| DeploymentRules | 格心、奇偶占地、区域、结构/塔墟和最近合法建筑落点；只注入结构及地面查询 |
| WorkbenchSession | 待放置对象、显式操作单位弱引用、预设、清场和暂停；UI 区分放置/选择，通过正式入口操作战场 |
| Unit、ControlState、AttackTimeline、ShieldState / KnockbackState | 通用单位、控制聚合、普攻状态、独立护盾层和击退轨迹 |
| MovementSystem、ArenaRules、路径搜索 | 移动、部署几何、局部避让、碰撞与寻路 |
| CombatInteraction / TargetProtectionState | 按来源判断新目标/效果准入、固定圣霭的唯一状态窗口及只读副本 |
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
- **工作台：**UI 在 `scripts/ui/development_workbench.gd`，模型预览和场景配方在 `scripts/ui/workbench/`；仍复用正式出牌/技能接口。WorkbenchAudioCatalog 只负责把当前形态/阵营的正式音频配置展开为试听条目，UI 保留播放与筛选；离线候选不混入正式清单。

## 需要保留的语义

StatusInstances 持有来源独立的窗口；仅有效来源参与强度聚合，高强度短来源到期立即退出，低强度长来源不能延长它。同源刷新/替换规则以[状态共通合同](status/CORE.md)为主维护位置，动作取消以[动作合同](status/ACTIONS.md)为准。

在途弹体保存出手时来源与形态，来源死亡后仍可命中，但不给死者回血或技能资源。音频与模型不驱动伤害、移动或联网状态。

协议版本、固定载荷与握手以[网络协议契约](reference/NETWORK_PROTOCOL.md)为准；读写同步更新。晚到表现按进度对齐，重复序号不重播。NetworkEntityLifecycle 拥有出生描述、销毁标记和快照屏障；同 Tick 由生命周期序号区分，快照可以恢复未知实体，旧局生成/销毁/快照不能污染新局。

## 维护与已知限制

核心测试由 `tests/mechanics_check.gd` 和 `tests/suite_catalog.json` 统一编排；每套件重建并释放自己的场景，支持选跑与反序，检查战斗对象和根节点无遗留。维护审计检查资源、链接、注册和孤立 UID，不能替代运行回归。

离线加工放 `tools/`，已退役素材放项目根目录素材库 `04-中间产物/`，已结束研究放 `docs/archive/`。不因内容相同就合并不同音频事件，不能删除模型外部纹理或可编辑源件。

领域执行通过 BattleContext 和公开查询/表现通知使用必要服务；资源预留也不消除实例化成本。性能和设备验证的缺口见 [开发状态](DEV_PLAN.md)，历史测量见 [结构验收](archive/2026-09-11/maintenance_validation.md)。

## 比赛与网络生命周期

终局由 MatchRules 返回胜者阵营与结束原因；Main 通过可靠 RPC 发送包含最终快照的终态信封。客户端先应用最终状态，再按本地阵营显示结果；相同终态幂等，之后普通快照与实体事件不能恢复战斗。终局清空命令、弹体、区域效果与常规战斗音频；本次水晶爆炸的独占播放器保留到自然结束，随后仅触发本地结果播报；返回菜单时释放本场 ENet 连接。

MatchSession 持有大厅/加载/运行/结束/断线阶段、唯一对手与命令序号。双方先确认协议版本、卡牌内容指纹及完整合法卡组，再分别加载战场并确认就绪；加载期间不推进权威 Tick。运行时部署/技能只接受绑定对手控制队伍 1 的当前会话请求，并按单调序号去重。卡组不能局中重注册；所有表现事件携带会话标识。规则算法或 RPC 协议变更必须提升 `MatchSession.PROTOCOL_VERSION`；卡牌内容变化自动改变指纹。加载超时 30 秒停止，断线通过统一终局入口清理并允许返回菜单；不提供局内续接。

## 状态与排程所有权

护盾由 ShieldState 独立拥有每层时间、生命、容量与衰减余量；Unit/Tower 仅委托添加、推进与吸收并提供总量只读视图。客户端塔快照使用独立表现值，不构造权威护盾层。主动命令的付款收据由 CommandPayment 持有原付款者弱引用及实际金额，CommandSchedule 统一作一次性结算：开始施放消费、存活取消退款、死亡/会话清场关闭收据。

CommandSchedule 持有等待部署的命令，不预留建筑占地。DeploymentRules 在卡牌建筑真正生成前提供完整部署合法性校验，冲突时确定性寻找最近合法格；全场无位置时保留到下一 Tick。生成后才加入结构与导航，太阳圆盘重建状态由最终落点决定。

音频区域时长只由 GameAudioManager._process 推进。WorkbenchSession 通过暂停端口请求 GameAudioManager.set_battle_paused，音频管理器保存原有控制暂停状态；技能效果系统不再推进或清理声音。工作台清场分别调用命令、弹体、法术、技能效果和音频所有者的公开生命周期入口。

ControlState 拥有硬控倒计时与副本状态替换；Unit 仍决定部署/行为阶段何时消耗本 Tick，Tower 通过同一对象读取控制；状态正时长向上取整到20Hz Tick。网络适配调用副本入口，不直接改写控制计时器。VisualActionSequence 只持有动作片段、裁剪区间、目标时长与游标，不引用实体、场景或播放器；UnitModel3D 保留动作优先级仲裁、控制覆盖及实际播放/材质处理。换模型、动作结束与死亡统一清理序列。

AttackTimeline 拥有攻击间隔、前摇、后摇与基础攻速表现时间的全部生产写入。Unit 在原阶段顺序调用推进、开始、命中提交、取消和重置接口；硬控取消清除旧间隔与未释放追加刀，施法/变形显式重置。命中与后摇设置仍分开，避免触发变形后再写回旧形态后摇。ModelVisualResources 管理模型动画库深副本与原始/Buff/受击/冻结材质，重新绑定和退场恢复原始覆盖并释放引用。UnitModel3D 拥有模型节点与动作仲裁/实际播放，VisualActionSequence 拥有动作序列进度，资源对象不读取战斗实体。

ProjectileSystem 独占客户端弹体目标与插值位置，快照写入和外部读取均不暴露内部字典别名；网络适配显式注入该系统，跨局统一清除客户端弹体。Main 拥有网络实体索引；ActiveSkillRoster 拥有技能注册索引，MatchRules 拥有计时/结束状态，Tower 拥有副本到死亡表现与导航释放的转换。网络只解码并请求相应入口，RPC 保留在 Node。

CombatResolver 持有阶段内命中记录、附带效果、存活收益和死亡提交队列；BattleContext 暴露该服务，BattleNumbers 与 Unit/Tower 的直接伤害入口在收集期间转交记录。每批完成后清空所有队列；可选 trace 仅用于测试记录 Tick、阶段、来源、目标、段和死亡提交。建筑自然生命周期在 combatants 收集之前单独预处理，固定参与者快照。CombatResolver 同时持有本阶段普通击退请求，按出生身份、来源事件序号和子序号排序后提交；身份在出生接入分配，不能在遍历攻击者时分配。

恢复护盾到期资格由 ShieldState 随层保存；tick 返回本次有效自然到期结果，Unit 消费一次，死亡和清除不能恢复。横排编队沿用同次部署身份与技能资格转交。

## 资源准备与表现复用

本场加载页至少保持 1 秒，并等待实际准备完成。MatchResources 持有双方卡组、递归召唤物/形态、四类小兵、地图、塔、水晶和世界/比赛音频；MatchModelPool 在遮罩后预建模型及实例独立动画库，用离树只读 Unit 驱动渲染样本，预热样本不参与战斗。样本保持隐藏直至本局释放，避免首次渲染缓存随样本销毁而失效。正式表现领取预建实例；完成死亡表现或更换模型后，已审计的无脚本模型及包装重置后回收，库存不足仍立即创建，不阻挡模拟。每路径最多64个闲置模型，依照编队、召唤机制、双方及两波系统兵线预算；互斥形态同路径共享容量，不覆盖各自预热配置。联机双方卡组校验完成后并行加载，双方就绪后才解除暂停，准备与等待共享30秒超时；取消停止后续预热，退出恢复树暂停状态。

技能预热覆盖完整动画库的采样、受击/冰冻/强化叠加材质、强化场景与死亡后续模型，以及 LolParticleEffect3D 动态命名的原生粒子依赖。粒子纹理/网格/材质模板提前建立并保留；绘制样本不注册战斗对象、不施放技能、不播放音频。纯 2D 几何技能图形没有额外外部素材，仍由已有渲染代码按实际事件绘制。

限时形态由Unit持有寿命、循环段与击杀刷新；可在启动窗口结束后计时，并复用active buff实现开启/刷新加速。客户端只读形态、位置、动作和下一击就绪快照，动画不驱动战斗。死亡语音death:voice与death独立选池，击杀刷新通过form:refresh派发声音。

### 同模型原位换形

UnitModel3D在包装同时提供`can_reuse_visual(scene_path)`与`set_visual_form(form_index)`并接受目标场景时，保留现有模型、骨骼、AnimationPlayer及可变资源，仅重置动作调度并更新映射。下一表现事件从原姿势开始混合。地面/空中根高度目标在首次装配时记录，避免攻击补高污染后续换形基准；其他单位继续使用原有换模型路径。此接口只读权威形态，不参与模拟。

StructureRushState拥有一次性建筑冲撞阶段与已命中集合；Unit负责控制门禁和固定Tick入口，MovementSystem负责不被接触修正的直线移动。表现通过已有动作窗口和朝向快照只读同步。

模型复用只移交模型节点与实例独立资源；UnitModel3D代理、来源信号、动作调度和附属特效不复用。模型池重置变换、骨骼姿势、网格选择、动画区间/循环及材质；包装需显式实现reset_pool_visual，未审计包装保留即时创建后备。实例动画库仍隔离，不能直接共享运行中会修改循环模式的数据。受击/冻结与强化材质为每实例最多六种组合，切换状态不复制材质。

本机Compatibility渲染器需要实际可见绘制。预热仍采样全部片段，但相同网格/材质/可见性组合只绘制一次；六种控制/强化材质组合保留实际绘制，force_draw(false)不逐次交换屏幕缓冲，状态之间不额外等待帧；相同初始化需求的样本合并，保留绘制资源与骨骼，停止并移除不再使用的样本动画库，不影响正式模型。原生粒子由本局卡牌的强化/弹体依赖族引入；普通对局含系统兵线，保守保留整个男爵粒子族。其9种已接入系统的配置、网格和模板是有限应用级缓存，运行材质逐粒子独立；曲线和概率表只编译一次，重复进入不增加缓存键。

启动执行配置、引用与路径校验；开发验证的CardDB.validate_all()默认继续执行完整资源加载、音频类型和特效实例检查。MatchResources记录本局缺失/加载失败，准备失败停止对局。加载计时与模型命中/缺货/回收计数可供性能入口读取，不逐Tick输出日志。

多单位卡的下牌来源保存在每个成员的 active_skill_card_id，部署编号独立保存在主动资格与工作台选择中；效果目标、资格转交与工作台替补共用存活部署成员查询。应用快照时先同步技能来源卡再同步资格。

龙王星落的普通/满层预警与实际落地爆闪使用独立表现事件，预警创建同时提交独立结果，固定落点，来源受控或死亡不取消；扩散波仍跟随权威半径。

普攻规则：普攻起手射程与命中宽限分离，普通单位完整后摇后移动；瑟提双拳结束转走时清除旧间隔。快照沿用原载荷结构，版本随 MatchSession.PROTOCOL_VERSION 同步。

## 扩展接口

CommandSchedule 的集合不对调用方开放：enqueue_* 接收明确参数并由内部构造命令，take_* 转交到期命令，cancel_skill/clear 负责一次性付款结算；has_pending_skill 查重。inspect_* 仅低频检查导出副本，生产 Tick 不复制全量排程。施法效果及结束奖励绑定 Unit.active_skill_cast_serial；冰冻/死亡取消依附后段，独立结果由效果系统持有自己的身份和完成记录。

ActiveSkillRoster.entry 提供单项只读视图，技能配置共享只读定义；权威消费走 consume，网络镜像走 replace_replica。CardCycle.consume 只变更牌序，Main 随后更新 UI；客户端只按可靠确认 replace_replica。

KnockbackState 只持有普通击退轨迹、剩余锁定时间与终止原因（强制位移尚未实现），Unit 先检查准入再替换；MovementSystem 继续做碰撞。形态切换、生命上限、待变形代次和技能资源目前在 Unit 的既有方法中统一拥有；未引入与其并行的状态实现。死亡替身/复生是新实体，不能和原位换形合并。

治疗、控制、护盾与位移继续使用各自准入入口；普通索敌与已释放命中分别检查，纯控制不以扣血成功为前提。不因删除旧过滤而创建新的隐身/不可选中系统。

工作台会话不读取整个 Main：注入放置、选中单位、清场、重建竞技场、暂停和视图更新端口。Main 保留节点创建/销毁与正式 play_card/preview_active_skill，预设与选择状态只在会话中维护。

整理前正文及历次版本描述仅作[历史证据](archive/2026-09-22/maintenance_architecture_before_cleanup.md)。新任务从[任务导航](AGENT_WORKFLOW.md)选择相关当前资料，无需先读交付记录。

按金币部署的选择和费用由CardDB提供纯查询，Main付款前固定实际生成ID，CommandSchedule持有排程副本。原卡ID保持手牌/主动资格，衍生ID走既有生成和网络路径，不新增专用英雄Unit。

DeathFormState持有一次性致死换形资格、等待Tick与衰血余量；Unit保持同一实体并在自然生命周期推进，零血等待者仍由快照保留。ShieldState独占爆炸盾到期资格；Unit将自然到期结果递交ActiveSkillEffectSystem，在原skill_effects批次消费，清场清空排队结果。

CardPlayHistory独占最近成功出牌与镜像部署代次；CommandSchedule持有已付款镜像副本。原卡ID负责模型、音频与技能定义，技能槽负责操作资格，两者不可再通过卡ID相等推断。主机可靠下发随机首手，客户端只应用确认。

BleedState由Unit/Tower各自持有，独占按来源的流血层数/窗口/余量；Main在combatants收集前段统一推进，CombatResolver依据实际命中施加流血并发放存活来源血怒及斩杀资格。血怒归StatusInstances，免费追斩归ActiveSkillRoster，与付费次数和冷却分别保存。

MatchCardGrowth持有每阵营局内成长和只读快照，Main在接受部署时固定实际定义，CardCycle仍只轮换来源牌。TerrainTraversalState归Unit，负责地形进入收益与普攻出地形门禁。UnitLandingQuery只查询连续几何；DashStrikeState由ActiveSkillEffectSystem持有，在原skill_effects阶段推进可受伤的穿单位位移与两段伤害。MovementSystem跳过突进实例的普通推挤；客户端只读位置、动作、成长快照。
