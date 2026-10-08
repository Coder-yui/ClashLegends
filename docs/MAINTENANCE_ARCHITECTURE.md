# 项目结构与维护边界

本页维护状态所有者和扩展入口。共同边界见 [AGENTS](../AGENTS.md)，代码目录见 [scripts 导航](../scripts/README.md)，验证方式见 [测试手册](../tests/README.md)。

## 模块职责

客户端输入反馈/操作请求 → Main 权威校验与付款 → CommandSchedule → BattleSimulation 固定阶段与批次结算 → 按接收方快照/表现事件 → 客户端UI、模型与声音。

| 层 | 状态所有者与职责 |
| --- | --- |
| 定义 | CardDB 注册逐卡四域；CardDefinitionCompiler 合并，CardShapeValidator 前置类型检查，CardValidator 校验语义与资源；共享定义递归只读 |
| 编排 | Main 装配节点、比赛生命周期、UI/RPC、固定阶段调用；Unit/Tower 通过 BattleContext 使用服务，不能反向探测 current_scene |
| 固定阶段 | BattleSimulation 编排同一权威 Tick 的状态、命令、技能、单位、移动、弹体与胜负；独立服务器、单机和工作台共用，客户端拒绝调用 |
| 比赛 | FixedStepClock 积压与 Tick；MatchRules 时间/胜负；MatchSession 双玩家身份映射/握手/独立命令序号；ElixirManager 金币；MinionWaveSchedule 兵线阶段、延迟条目与有序生成请求 |
| 卡牌命令 | CardCycle 服务端/单机完整牌序与独立随机源，ClientHandState仅保存客户端四张手牌/下一张/版本，ClientInputState持有请求反馈；CardPlayHistory 最近成功出牌/镜像代次；MatchCardGrowth 每阵营局内成长；CommandSchedule 排程（含不依附来源的在途召唤），CommandPayment 一次性付款收据 |
| 部署 | UnitSpawnRequest 具名生成参数（不改变网络载荷）；DeploymentRules 区域/建筑合法落点；PreDeploymentSweep 预部署轨迹与扫掠查询；部署命中集合随排程条目存活 |
| 通用实体 | Unit/Tower 汇合权限、委托状态并执行生命周期；普通新卡复用 Unit，不建立英雄子类 |
| 控制与攻击 | StatusInstances 来源独立窗口；ControlState 硬控/减速；AttackTimeline 前后摇、间隔、基础攻速表现时间 |
| 生命状态 | ShieldState 每层生命/时间/衰减/恢复与爆炸资格；BleedState 来源叠层/窗口/余量；DeathFormState 致死换形资格、等待 Tick 与衰血 |
| 位移 | MovementSystem 碰撞与移动；NavGrid 动态导航格、nav_lane_layout 静态路线场、BattlePathSearch 搜索；KnockbackState 普通击退；StructureRushState 建筑冲撞；TerrainTraversalState 穿地形门禁；UnitLandingQuery 连续几何落点 |
| 命中与技能 | CombatInteraction/TargetProtectionState 准入与固定圣霭；CombatResolver 阶段命中/附带效果/收益/死亡队列；ProjectileSystem 弹体；SpellSystem 法术与可选速度配置的在途时钟；ActiveSkillEffectSystem 技能效果与 DashStrikeState、OrnnChargeState |
| 周期队伍普攻增幅 | TeamAttackBoostSystem 主机固定 Tick 选择未增幅友军并写入 Unit 永久倍率；快照只复制倍率，不复制周期时钟 |
| 主动资格 | ActiveSkillLifecycle 协调准备、起手、动作和排程，CommandSchedule 按身份结束/取消；ActiveSkillRoster 技能槽、编队转交、次数、冷却、免费追斩；效果执行身份归 CommandSchedule 与 Unit.active_skill_cast_serial |
| 联网 | NetworkClock拥有RTT/时钟采样，NetworkCommandState拥有公开命令准备记录，visit仅提供只读字典，NetworkPlayback拥有客户端快照/事件播放时间轴，仅入队后重排，保持同Tick事件先于快照；NetworkEntityLifecycle 出生/销毁/快照屏障；NetworkSnapshotSystem 编解码与状态投影；RPC 保留在 Main 节点 |
| 表现 | UnitPresentationState 只读视图；PresentationConfig 形态选择；PresentationEvents 真实事件能力；UnitModel3D/TowerModel3D/BattleEffects2D 只读驱动图像；SkillEffectPresentation 拥有范围/护盾视觉实例、渲染计时与网络去重；GrowthEffect2D绘制成长气浪/叶片，GrowthMark3D以共享网格和深度测试表现持续花叶纹样 |
| 动画与资源 | MatchResourcePlan 展开卡牌/技能声明；EffectResourceManifest 解析效果文件；VisualActionSequence 片段进度；ModelVisualResources 实例动画库与材质；MatchResources 本局资源强引用；MatchModelPool 预热/领取/回收 |
| 音频 | GameAudioManager 事件消费、播放器、区域时钟、暂停与清场；default_bus_layout.tres 持有总线压缩/限幅，见[动态混音](AUDIO_INTEGRATION.md#通用混音动态处理)；不由技能系统推进音频 |
| UI 与工作台 | CardDetails/CardArt 详情与卡面；WorkbenchSession 选择和操作会话；模型预览、声音目录、牌库及窗口布局各有独立组件 |

## 改动应落在哪里

- 普通新卡：逐卡定义、注册、正式素材和单位文档。新增字段必须有读取方、schema/validator 与回归。
- 新规则：扩展对应所有者；跨客户端可见的状态同步更新协议读写。不要在 Main 增加领域系统私有数组的别名。
- 新表现：读取状态或真实事件；缺事件时补派发、消费、去重，不能从动画回调结算伤害。
- 工作台：`scripts/ui/development_workbench.gd` 负责界面，`ui/workbench/` 提供组件；玩家、AI、RPC、工作台出牌统一走 `play_card()`。
- 离线加工与复现：放 `tools/`。正式资源只进 `assets/`，候选和验证产物留本地开发素材库。

## 需要保留的语义

独立服务器/单机固定 20Hz；每帧最多赶 4 Tick，或已耗时 8 ms 后停止继续赶步，积压保留，单 Tick 不截断。客户端只请求操作、接收快照及事件，不自行解除控制、判伤害或提前换形。

同源状态刷新/替换、异源独立到期、强度聚合见[状态共通合同](status/CORE.md)；动作取消与权限见[动作合同](status/ACTIONS.md)。状态正时长向上取整到 Tick。AttackTimeline 的取消、命中与后摇写入分开，避免形态变化后写回旧阶段。

CombatResolver 按阶段收集并统一提交；单位行动阶段先固定 combatants 参与者名单，再推进建筑自然生命周期；自然退出生成的对象不回头加入本阶段名单。普通击退按出生身份、来源事件序号及子序号排序，不以遍历顺序分配身份。真实在途弹体保留出手来源和形态；来源死亡后仍可命中，但不给死者生命或技能资源收益。规则细节见[卡牌机制](CARD_DESIGN.md)、[数值](NUMERIC_SYSTEM.md)和[移动接触](BATTLE_CONTACT_MODEL.md)。

## 比赛与网络生命周期

MatchSession 在服务器绑定两名玩家，独立保存玩家身份、阵营、连接和请求序号；两端校验协议版本、内容指纹和合法卡组，再分别加载并确认就绪。服务器无本地玩家，不实例化界面、模型池及音频管理器。加载不推进战斗；准备和等待共享 30 秒超时，局中不能重注册卡组。请求按会话/连接映射阵营/各玩家单调序号校验，所有表现事件携带会话身份。

NetworkEntityLifecycle 按生命周期序号区分同 Tick 生成与销毁；快照能恢复未知实体，旧会话不能污染新局。ProjectileSystem 独占客户端弹体目标与插值位置，外部只取副本；Main 持有网络实体索引。

终局可靠信封包含最终快照；客户端先应用状态再显示结果，重复终态幂等，普通快照不能恢复战斗。终局清命令、弹体、区域及常规战斗音频，水晶爆炸独占音轨自然结束后触发本地结果播报；客户端返回菜单释放本场 ENet；正常终局两端离开或断线失败后服务器重建干净会话。规则或载荷变更须提升协议版本，精确契约唯一入口为[网络协议](reference/NETWORK_PROTOCOL.md)。不支持局内断线续接。

## 状态与排程所有权

CommandSchedule 通过 enqueue/take/cancel/clear 管理内部集合；inspect 仅用于低频检查，生产 Tick 不复制全量集合。付款收据绑定原付款者：开始施放消费、存活取消退款、死亡/会话清场关闭。等待部署不预留建筑占地；真正生成时选择最近合法位置，全场无位置则保留到下一 Tick。凝滞等不可推动占位的玩家部署复用这一策略，编队先整体规划；可推动单位含冰冻继续自然碰撞。召唤/复生使用全场几何，不套用玩家部署范围。

ActiveSkillRoster.entry 是单项只读视图，权威消费走 consume，客户端走 replace_replica。多单位卡的来源卡、部署身份与技能槽分别保存；转交只查询同次部署的存活成员，不能以卡 ID 相同推断资格。CardCycle仅在权威端维护完整牌序与版本；可靠确认只下发本方四张手牌与下一张，ClientHandState按版本及请求序号更新，客户端不洗牌、不推导隐藏队列。

盾层自然到期由 ShieldState 返回一次性结果；死亡和清除不能触发恢复或爆炸。盾层和StatusInstances减伤自然到期的爆炸统一通过queue_expiry_explosion递交技能效果批次；流血由 Unit/Tower 各自持有，CombatResolver 发放存活来源收益。形态、生命上限、待变形代次和技能资源由 Unit 汇合，死亡替身/复生的新实体不能与原位换形混用。

技能后段绑定施法身份；冰冻/死亡取消依附动作，龙王星辰等独立结果持有固定落点和归因。DashStrikeState 在 skill_effects 阶段推进可受伤的穿单位突进，OrnnChargeState 按固定速度采样地形/建筑并结算沿途命中与停点范围效果，MovementSystem 跳过这两种状态的普通推挤。状态对象不直接写 Unit 的位置、锁、寻路或形态字段；Unit 的位置转换、突进完成和致死换形接口统一应用，旧施法序号不能释放新施法。PreDeploymentSweep 只在权威端得到伤害目标；客户端采样轨迹只用于显示。

### 公共战斗事实

Unit持有唯一 `combat_idle_seconds`，旧状态推进前采样持续战斗条件。成功伤害及控制/减益入口通过CombatInteraction记录双方事实，CombatResolver保留批次来源；StealthState只消费同一空闲时长，不独立推进生产计时。瑟提资源衰减使用相同时长与自身阈值。主动位移控制取消沿用动作序号/累计取消屏障，不改变同批伤害或独立结果合同。奥恩被动系统不接入公共脱战门禁。

## 资源准备与表现复用

加载页至少保持 1 秒且等待实际准备完成。MatchResourcePlan 在双方卡组与技能选择确定后，按阵营计算可达卡牌、召唤物、形态和技能；MatchResources 只收集该计划内的资源及四类兵线、地图、塔、水晶与声音；正式加载入口以最多 128 个未完成请求组成的引擎任务队列后台读取尚未缓存的资源，主线程先接收完成请求，再同帧补满队列，保留强引用并检查类型，不能提前调用阻塞等待。已知卡牌重复请求直接复用本局集合，不重新解析整局粒子JSON。取消后不新增请求，收尾已有请求；加载场景销毁时将已发请求移交短命节点领取完成结果并自行退出；资源缺失或加载失败停止准备。命令行单机同样经过加载页；工作台和内部测试保留全卡同步入口，正式加载时 UI 不提前同步加载整副卡组。CardDB 启动校验路径和配置，开发验证继续执行完整资源/音频类型/特效检查。

MatchModelPool 在遮罩后预建模型和实例独立动画库。离树只读样本不参与战斗或发声；Compatibility 渲染器实际绘制不同网格/材质组合，隐藏保留样本与绘制资源。预热遍历动画起点及可达的受击/冻结/强化材质组合；没有冰冻时跳过冻结采样。效果提供者声明全场 `stasis` 目标状态时才加载金身贴图、创建并绘制金身材质；防御塔同样在遮罩内绘制并恢复，免疫水晶不参与，有隐身能力的模型另绘制透明隐身材质。预部署场景调用真实纯表现 setup/advance 接口，分段采样入场过程；相同需求合并，互斥形态容量不覆盖预热配置。模型实例/动画采样在加载遮罩内按约 32ms 批次让出主线程（单个实例或驱动绘制不能截断），取消时立即隐藏预热样本；模型池容量不因此扩张。

ModelVisualResources 对未压缩的纯数值骨骼/混合形状动画使用 copy_track 构建实例独立副本；资源值、事件、压缩轨道或脚本/元数据扩展仍完整深复制，同库别名保留。无脚本模型只复制配置引用的动作（递归包含键和值、所有形态并集）及 RESET；脚本包装和扩展动画库保守保留完整片段。动画复制可分步完成，半成品不参与战斗，源库保持不变。MatchModelPool 仅在资源所有者明确将强化后三态构造为基础前三态的引用别名（没有任何强化材质）时，省去后三次重复绘制；不以材质ID推断参数相同。可达材质状态及附属强化效果推进后的首次绘制保留；有强化材质时保留其独立绘制。场景树、动画副本与实际绘制仍在主线程，后台线程只读取资源；资源闭包、实例预算和双方 ready 门槛保持原流程。 本局闭包包含冰冻法术时，加载遮罩下预建并实际绘制一个冰面槽，随后隐藏；不创建法术状态、伤害或声音，开战后复用该槽。腐蚀的粒子纹理由依赖清单纳入本局资源集合；加载时用独立表现字典分帧采样 0–4.75 秒，覆盖延迟出生层并保留隐藏样本，不写入正式法术集合。新增预热不等于所有事件/动态材质组合已经穷尽；按首次事件测量继续补充。

模型池只回收已审计模型/显式支持 reset_pool_visual 的包装，重置骨骼、网格、变换、动画循环区间及材质。每路径容量最多 64，按编队、召唤与兵线预算；开局轻量模型准备首轮（至少完整编队），脚本包装或实测实例化超过 1ms 的路径仍完整预建。局中在单位表现更新后补回首轮闲置库存，受闲置加活跃数量的原容量约束；慢帧（>20ms）跳过，实例化、包装准备、材质与单动画副本分阶段，动画批次目标 1ms。场景树操作仍在主线程，单个引擎操作不可抢占；批次超过 2ms 后停止该路径补充。隐藏且禁用处理的半成品只在完整准备后入池，退场清理。缺货仍同步创建以保持完整表现，不能宣称绝对无卡顿；记录补充耗时、暂停和缺货。UnitModel3D 代理、信号与附属特效不复用。换模型/退场恢复覆盖材质并释放引用。

### 同模型原位换形

包装同时提供 can_reuse_visual(scene_path) 与 set_visual_form(form_index) 且接受目标场景时，保留模型、骨骼、AnimationPlayer 和实例资源，只重置动作调度、更新映射并从原姿势混合。首次装配记录根高度，避免攻击补高污染换形基准；其他单位仍走换模型路径。

## 扩展接口

WorkbenchSession 只注入放置、选中、清场、重建、暂停及视图更新端口；Main 保留节点生命周期与正式操作入口。模型/声音页只读正式配置，候选使用通用离线展台。工作台不承担验收持久化或报告导出。

治疗、控制、护盾与位移分别走准入入口；新选取和已释放命中分别判断，纯控制不能依赖实际扣血。强制位移复用唯一外力状态、稳定提交顺序与通用落点查询；途中无碰撞仅由其状态开启，不放开普通击退。未支持的禁锢等不得因相邻机制存在而声称完成，见[实现现状](status/IMPLEMENTATION.md)。

## 维护与已知限制

自动测试按 contracts/combat/deployment/status/presentation/ui/network/cards 分类；目录内测试由唯一注册表编排，共享夹具不注册。全卡内容检查、共通机制与逐卡差异各有覆盖所有者，具体约定见[测试手册](../tests/README.md)。

Main、Unit、UnitModel3D 仍是较大的编排类；后续拆分应以单一状态所有者和明确生命周期为边界，不按行数机械切割，也不通过更多转发层掩盖耦合。已按边界收拢兵线、施法协调与生成请求；部署几何和场景装配仍留在 Main，后续按实际扩展需要维护。

设备、性能和联网未验证范围见[开发状态](DEV_PLAN.md)。历次记录见[归档](archive/README.md)，日常任务从[任务导航](AGENT_WORKFLOW.md)进入当前专题。

## 法术加载与绘制准备

卡牌及技能的 `resource_dependencies` 声明额外效果，EffectResourceManifest 向对应提供者解析文件清单，MatchResources 收集图标/音频与效果内部纹理、Shader，并登记原生JSON/网格文件；SpellEffectWarmup仅执行提供者的采样配方，不再维护英雄名单、技能索引、DATA或SAMPLED中央表。腐蚀沿用自己的dependency_paths与prepare_visual，冰冻沿用现有绘制准备。电击、大型电击、凝滞、爆破酒桶在加载遮罩内通过SpellEffectWarmup创建独立样本，覆盖飞行、拖尾、预警、抵达和真实命中层；实际提交绘制后保留网格/材质引用并清理样本节点。它们不进入SpellSystem权威数组，不发布卡牌事件或音频，取消加载后不再继续准备。无对应法术的卡组不预热该法术。 原版冰鸟普攻/风暴、赛恩施法/护盾/爆炸、龙王普攻吐息、天使光剑/焰浪、格温圣霭和小炮弹体/急速射击也走同一依赖收集与实际采样绘制；延迟出生层补首个可见采样。播放器明确关闭的层不再加载其独占纹理/网格。

双方各前两个槽位只带入已选的一个主动技能；双方同卡不同选择取并集。只有主动槽中的镜像允许复制本方其他卡牌的已选技能（未记录选择时与战斗一致默认为第一个），普通槽镜像不扩展主动资源，也不扩展敌方技能。成长、升级和编队继承资格，独立召唤物不会凭空获得主动。金克丝与剑魔的主动专属形态按资格收集，纳尔变形、赛恩复活等被动仍保留。格温圣霭、赛恩W、烈阳护盾及小炮Q按对应技能过滤；冰鸟和小炮普攻、龙王吐息、天使焰浪始终随可达卡牌收集；冰冻的普通冰面与强化减速场分别准备。

模型池和正式附属特效挂接共同使用该计划；小兵系统波次不自动预热男爵之力，金克丝与诺手的被动附属效果不被误删。梦魇只准备已选P或W层。事件音频复用 PresentationEvents 能力表过滤。金克丝/飞机弹体贴图改为按实际依赖加载，避免通用弹体脚本载入未登场卡牌的贴图。凝滞法术基础效果声明金身目标状态，普通槽凝滞同样需要金身；未携带凝滞时模型和防御塔不创建金身材质或读取贴图。共享的模型/动画库、脚本、图集和复合JSON按文件加载，不拆分其中的数据；开发工作台可任意换卡换技能，保留不受固定对局计划限制的全量模式。

原生sampled/systems/mesh JSON是运行依赖，必须在export_presets.cfg的include_filter覆盖；仅Godot资源导入成功不证明导出包包含FileAccess读取的JSON。验证使用SpellWarmupSuite、实际绘制预热和导出PCK读取检查。预热覆盖不等于已证明所有硬件上没有首帧停顿，性能结论需单独测量。


资源扩展遵循[卡牌资源依赖契约](CARD_DESIGN.md#表现资源依赖契约)和[新卡资源步骤](NEW_CARD_CHECKLIST.md#赛前资源声明)。`fields` 把主动专属形态与附属效果归属到技能；镜像以复制能力声明扩展本方技能，中央规划器不按英雄 ID 判断。潘森、蛮王等包装中的动态原生粒子、图奇隐身和余震爆炸也通过效果契约登记；潘森依赖与运行层开关共用。未使用的酒桶节点不读取原生JSON，公共余震/凝滞脚本不提前加载专属纹理或拖尾Shader。`MatchResources.raw_files` 记录原始文件，`resources` 保留加载后的引擎资源强引用；场景/图集/动画库以完整文件为边界，不能承诺文件内部未选片段不驻留。
