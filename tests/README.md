# 测试与验收

`tests/mechanics_check.gd` 是 Godot 套件执行入口，`suite_catalog.json` 是套件 ID、脚本、方法、场景与领域的唯一注册表；日常由 `tools/dev.py verify` 按影响选择验证计划。原始 Godot 入口必须显式选择 `--suite=ID`，或在确有必要时使用 `--all-suites`，裸命令不会隐式全量。普通新卡复用全卡内容契约，只有独特机制才增加专项用例。

## 按影响选择验证

先看改动所属模块，再追踪直接消费者。纯文档只核对链接、事实和差异；局部代码运行本模块及直接消费者；协议、时序、生命周期等跨模块变化才增加相关领域与集成边界。全量只用于确有必要的重大跨域改动或里程碑，同一代码身份通常只需一次；失败修复后先重跑失败范围，有新增影响才扩面。

| 验证类型 | 常用入口 | 证明范围 |
| --- | --- | --- |
| 纯文档、链接与导航 | `verify --plan` 后 `verify`；或直接项目审计与 `git diff --check` | 审计与一致性；不启动 Godot，不证明运行行为 |
| 局部代码、单卡或工具 | `python3 tools/dev.py verify --plan` 后执行 `verify` | 本模块与直接消费者；静态/Python/引擎步骤按计划需要选择 |
| 明确单领域或专项 | `verify --group status` / `verify --suite OrnnSuite`（均通过 tools/dev.py） | 显式选择范围；不因此附带最终全量要求 |
| 网络协议、快照、生命周期 | 先看影响计划，按变化追加 `--network` 或 `--network-boundaries` | 相关领域及本机三进程边界；网络选项不意味着必须跑所有机制 |
| 重大跨域或统一里程碑 | `python3 tools/dev.py verify --full` | 显式全部套件及安全静态/Python门禁；三进程仍按需要单独追加 |
| 模型、UI、动画、音频 | 工作台及[专项场景](../tools/demos/README.md) | 实际渲染/试听，需人工验收；headless通过不能替代 |
| 局部性能 | 选定机制套件后追加 `--profile-maintenance` 或对应专项工具 | 同条件前后比较；不因性能定位重跑所有压力档，不当成FPS或正确性门槛 |

历史证据只供追溯；退役配方从 Git 历史读取，不作为当前可运行命令。注册ID保留稳定命令接口，不为大小写统一而改名。当前入口清单通过 `verify --list-suites` 查询，数量以catalog与本次结构化结果为准。

金克丝专项 `--suite JinxSuite` 覆盖换枪次数/冷却、在途弹体、空地溅射、机枪三层、建筑/防御塔/水晶助攻边界、命中后自然到期/衰血致死及超时排除、移动切枪下肢同相位混合/结束不重启及下肢武器隔离、凝滞、同批互杀与快照；6秒叠层/刷新、120Tick到期、躯干后方速度线出生分布、爆炸45像素外沿及层数/剩余时间网络往返。

网络回归还覆盖已解码快照的递归只读、入队到出队期间会话/终态/同Tick变化、晚字段坏包整包拒绝且无部分写入、双端私有钱包/成长、无接收者零采集、终局一次公共采集及队列双限/引用释放；按实际序列化构造近上限混合包，检查16包接纳与第17包预算拒绝，预算定义见[协议契约](../docs/reference/NETWORK_PROTOCOL.md)。session与maintenance覆盖100次相同成长零手牌重建、单次进度变化刷新，以及全正式主动技能费用查询与完整施法配置等价。重复工作性能实验另见[性能工具](../tools/performance/README.md)，不以测试耗时推断FPS。

## 查看计划与执行

```sh
python3 tools/dev.py verify --plan
python3 tools/dev.py verify
```

`--plan` 只读输出 JSON，不创建证据目录、不查找或启动 Godot。无选择参数时，计划读取相对 HEAD 的暂存与未暂存改动、重命名两侧和未忽略的新文件；无改动或纯文档只有审计与差异检查。局部变化按风险和直接依赖选择步骤，不再固定执行导入、全套 Python 和全部机制。

需要按本轮已明确文件选测时，使用 `--changed PATH [PATH ...]`，可重复；它显式替代 Git 改动集合。例如：

```sh
python3 tools/dev.py verify --plan --changed scripts/battle/match_card_growth.gd
python3 tools/dev.py verify --changed scripts/battle/match_card_growth.gd
```

已有未提交工作较多时，记录中说明哪些文件属于本轮、哪些已有代码身份和通过证据可复用。不能省略已受影响文件，也不能把之前代码的结果当作当前通过。未知路径在计划列为 unknown 并阻止自动执行；共享生命周期、共享数据等高影响入口或自动范围过广也要求显式确定边界。先补充明确的 `--suite` / `--group`，或经判断显式 `--full`，不自动升级全量。`--full` 与 `--suite` / `--group` 不混用。

计划可能包含审计、相关 Python 检查、版本化资源输入/产物精确核对、Godot 导入、卡牌数值核对、所选机制或明确请求的联网；只执行本次需要的步骤，失败即停。通用工具测试不执行素材导入配方。普通`verify`保留既有每步默认600秒及`--timeout`语义，不自动套用新的Mac内存政策，也未因此获得RSS/系统压力/心跳保证。通过`--godot`（或GODOT_BIN）、`--output`指定环境。

本轮受保护入口须显式选择：

```sh
python3 tools/dev.py verify --guard-profile authority-logic --suite GrowthSpatialSuite --suite StructureRewardSuite --timeout 20
```

`authority-logic`只支持GrowthSpatialSuite、StructureRewardSuite、AuthorityTimingSuite、LightweightContractSuite、StartupNetworkBoundary、WorldOwnershipSuite、RuntimeOwnershipSuite、UnitMutationSuite与StrictContractSuite九个经审查的轻量套件及已有导入缓存；导入、数值导出、其他套件、正式加载和三进程network均不属于该政策，混用会拒绝，不降级为普通运行。仅macOS受支持，其他平台或监控不可用明确拒绝受保护启动；普通跨平台入口不依赖这套Mac监控。计划JSON明确输出所选政策。该模式默认20秒，显式`--timeout`必须在(0,20]，超出直接报错，不静默截短；普通入口仍默认600秒。

轻量预算取RSS上限768MiB与估算可用量减2GiB的较小值，至少须能分配512MiB，即正常压力且估算可用至少2.5GiB；8GiB物理内存机器有足够实际余量也可运行。运行中可用量低于2GiB或压力变化即停。不再套ready+256MiB额外增长上限，绝对RSS预算仍生效。主线程心跳首次6秒、之后2秒，脚本30FPS；RSS轮询目标0.1秒、系统内存每秒取样，三个系统内存命令共用0.2秒截止，超时即监控失败。频率是轮询目标而非硬实时保证，进程查询/调度可带来短延迟；不得串联多个2秒查询。旧但尚未读取的心跳按文件实际年龄判断，不以读取时间刷新。已有进程按所选引擎的argv/规范路径及Godot/godot/godot4名称检查，只允许编辑器共存，不终止这些进程。停止后核实整个自有组无活进程，证据在`mechanics-guard/watchdog.json`；不保证GPU或系统恢复。正式加载另沿用`match_loading.py`既有政策，不与轻量政策混同。

`UnitMutationSuite`使用同一无资源authority_battle，覆盖生命/属性/状态/位置具名写入口、HitReceipt提交、首次命中回血、死亡复生和完整验证后的副本恢复；它是同批生命/治疗/零伤害收益、持续攻击/技能同刻命中及释放引用六组检查的唯一执行入口；原CombatBatchSuite/maintenance_contracts删除重复调用，原检查正文迁入本套件，死亡、控制、身份与提交顺序未删。它不运行这两个旧套件的其他内容。`verify`每次结果的identity同时保存逐文件`files_sha256`（删除项为null），覆盖生产、测试和工具，可精确比较后续变化。

`GrowthSpatialSuite` 与 `StructureRewardSuite` 使用 `authority_battle.gd` 复用正式Main服务、出生、空间查询、20Hz模拟、resolver/弹体和快照字段应用，不创建UI、模型或音频、不监听端口。前者覆盖成长/换形/牺牲强化的空间交接、真正未强化客户端首次接收更大半径，以及重复副本不叠属性/不调用权威空间修正；后者通过真实弹体覆盖同塔先命中再致死仅一层、同批两塔两层、首次/队友补刀、过期、同批互杀、凝滞和建筑亡语。它们证明所列逻辑边界，不代替画面/声音或三进程联网验收。

`AuthorityTimingSuite`复用同一无表现夹具，覆盖先知R延后控制/独立区域的施法身份、引导中周期召唤与受控待发/已发序列、梦魇护盾收集期一次预留与提交后攻速收益、攻速开始/刷新/到期及减益叠加、同批死亡、塔首击/间隔精确Tick，以及正式非immediate的卡牌大师/潘森创建边界与扫掠。它不读取模型、UI或音频，不监听网络；合并相同场景下的阶段断言，避免按前摇/后摇/间隔重复造局。可单独使用`--guard-profile authority-logic --suite AuthorityTimingSuite --timeout 20`，不扩大到其他套件。

`LightweightContractSuite`将表现生命周期、配置契约与启动失败边界合并在一个限定专项中：复用无表现权威夹具，直接投递技能事件、可靠销毁与快照补删；检查固定区域寿命、无效来源/取消屏障、当前全卡无资源校验、跨引用坏容器、退役字段迁移和凯尔详情。坏容器矩阵在一个引用字段保留五种形状×两种注册顺序，其他五个引用字段各保留代表坏形状×两种顺序；整表预检先于引用读取，避免把相同预检重复六遍。音频只读取约367KiB的三个已导入约里克强化片段，检查原轨/循环副本、跟随和暂停/消费/死亡清理，不准备其他声音。启动失败通过注入，不加载资源或绑定端口；正常平局直接检查终态与文字。它不实例化模型/UI、不预热、不运行完整音频/内容/表现套件，不启动联网或重渲染。使用`--guard-profile authority-logic --suite LightweightContractSuite --timeout 20`；此明确白名单没有降低监督预算，重型套件仍拒绝。

`StartupNetworkBoundary`复用同一个lightweight_contract_suite.gd，仅选择`check_network_failures`方法，不执行该文件全批或音频检查。无资源、端口、UI或重载，通过状态注入覆盖客户端/服务端LOBBY、LOADING、RUNNING分流、单次中止/终态与重复调用幂等；新MatchSession可按原握手门禁完成准备并拒绝旧身份。`_network_peer`从未创建，因此null仅说明夹具初态；关闭和服务端重建只记录入口请求，不证明真实peer关闭、重连或服务端场景重建。命令为`--guard-profile authority-logic --suite StartupNetworkBoundary --timeout 20`。

`RuntimeOwnershipSuite`使用同一无资源权威夹具，覆盖无效/重复请求零副作用、同一账户支付与取消幂等、主动资格替换/编队转交、AI绑定、出生Tick、独立批次及收集→效果→收益→死亡顺序、比赛/加时/终局，以及客户端只发送请求并应用副本。TracingCombat仅记录既有正式阶段后调用super，不替换结算逻辑。新增专项显式纳入authority-logic白名单，限20秒、原内存/压力/心跳保护；不运行UI、模型、音频、端口、重预热或多进程联网。

已有缓存的局部 GDScript 或显式套件默认不重复 editor import；资源、场景、项目配置、缺失类缓存、新增 `class_name` 或显式全量在确有引擎检查时按计划导入。需要主动重建缓存可加 `--import`；它不运行素材制作配方。

证据默认在 `ClashLegends-开发素材库/04-中间产物/构建与验证/verification/<时间戳>/`。result.json 记录提交、脏工作区、文件摘要、引擎版本、命令、耗时与结果；运行中工作区变化判失败。输出目录必须尚不存在。

机制通过要求：正常退出、无脚本/资源错误、唯一结构化结果、所选套件全部且仅完成一次、失败数为零，以及最终“全部通过”。断言数不是门槛。结构化结果包含每套件耗时、检查数和失败数，方便定位昂贵用例；不以单次耗时证明性能改善。

下列为按需单步定位，不是每次修改必跑的固定流水线：

```sh
python3 tools/maintenance/audit_project.py
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script tests/mechanics_check.gd -- --suite=ProjectileSuite
git diff --check
```

## 独立套件与顺序隔离

```sh
python3 tools/dev.py verify --list-suites
python3 tools/dev.py verify --group combat
python3 tools/dev.py verify --group deployment --suite MinionSquadSuite
python3 tools/dev.py verify --suite OrnnSuite --reverse-suites
```

重复 `--group` 或 `--suite` 取并集，按注册顺序只执行一次；未知名称报错。显式选择默认不纳入无关的 Git 脏文件；如需同时分析已知文件，另加 `--changed`。选跑只证明该范围。原始 Godot 入口支持 `-- --list-suites`、`-- --suite=ProjectileSuite`，以及与选择一起使用的 `--reverse-suites`；领域与影响选择由 Python 执行器展开。需要完整原始执行时使用 `-- --all-suites`，日常优先用有计划和严格日志的 `verify`。

每套件固定种子 12345，按需新建菜单/对局，关闭自动主循环、AI 与常规兵线；结束释放场景，检查 combatants 和根节点无遗留。套件内部多个用例仍须清理自己的临时状态。跨套件不能复用可变场景来换取速度。合并重复检查应把同一合同交给一个执行所有者；其他套件的独有集成场景继续保留。删减映射与当次口径见[本轮收尾记录](../docs/deliveries/2026-10-18_测试精简与文档封板.md#测试精简与覆盖映射)，不把历史断言总数当作质量目标。

## 分类与覆盖所有者

| 目录 / group | 负责范围 |
| --- | --- |
| `suites/contracts/` / contracts | 四域、类型、递归只读、全卡资源/包装/动画/卡面、时钟与所有权合同 |
| `suites/combat/` / combat | 数值、索敌、弹体、批次公平性、兵线建筑、自然到期、接触寻路、普通击退 |
| `suites/deployment/` / deployment | 部署区域/建筑落点、付款、编队资格转交与批次隔离 |
| `suites/status/` / status | 通用主动时序、控制前后边界、盾层、限时形态 |
| `suites/presentation/` / presentation | 动作、材质、插值、共享特效、声音归属与终局播放器生命周期 |
| `suites/ui/` / ui | 备战、工作台交互、经典场景 |
| `suites/network/` / network | 单进程协议/会话/副本/终态；三进程脚本由网络模式单独调度 |
| `suites/cards/` / cards | 逐卡特有规则、数值、动作与特殊效果；六种普通小兵编队集中在 MinionSquadSuite |
| `suites/battle_suite.gd`、`suite_utils.gd` | 共享绑定、断言、固定Tick、既有模型代理查询与内容夹具；不单独注册 |
| `fixtures/` | 网络场景、固定牌序辅助、原始寻路输入及 ProjectileSuite 调用的 `projectile_view_checks.gd` 子检查 |

新增用例先找所有者，遵循以下去重边界：

纯内容/状态夹具放SuiteUtils；依赖当前对局的固定Tick、单位夹具及模型查询放battle_suite。不同生成路径（真实play_card、直接Unit.setup、带部署覆盖）不强行合并，否则会隐藏部署或归属差异。场景释放与随机种子仍只由统一入口管理。

当前专项覆盖包括：

| 套件 | 关键边界 |
| --- | --- |
| OrnnSuite | 独立CD就绪与动作准入、单锤节点、控制/主动抢占与发射前后、永久普攻增幅排序/预留/不重复、伤害取整、固定速度冲锋及障碍撞停结果 |
| StructureRushSuite | 先锋准备锁定目标；双方真实防御塔前经play_card早放/晚放建筑，不重置准备，冲撞中接触挡停；偏离路径不挡停及恢复时钟 |
| BuildingMinionSuite、BuildingExpiryBoundarySuite | 建筑周期产出、寿命与衰血；墓碑受伤死亡、自然到期、回血后到期、衰血致死均只召唤两只；双方死亡生成碰撞、新生对象不参与同Tick旧行动名单 |
| LuluSuite | 部署首批/7秒周期、左右生成、受控待发、目标优先级/排除、永久生命/体型、换形、不重复及空目标/目标消失退款；成长同步另归网络生命周期套件 |
| CombatActivitySuite | 战斗事实、纯护盾承伤归属、硬控/减益阻止空闲、瑟提1秒与图奇2秒、位移受控取消及凯隐停步后技能保护、同批路径伤害保留 |
| ForcedDisplacementSuite | 两阶段落点、保速与行动锁、河流/斜线预算、动态建筑/凝滞占位、体型/空地变化、无解重试、批次接管、实际撞塔六虫/死亡八鱼 |
| NavigationCollisionSuite | 环形最近通行格的稳定同分顺序、无解回退和重叠阻挡释放；原始A*夹具约束搜索次序 |
| TargetDummySuite | 不移动/不普攻、减伤先于护盾、最强聚合、49/50Tick、范围/友军排除、冰冻/凝滞、死亡取消、自然寿命、费用/次数/CD、快照与非法配置 |
| CorkiSuite | 首个空/地碰撞、空地范围、友军/凝滞排除、射程空飞、来源死亡、三次正式付款/CD/伤害序列、共享定义不变及非法字段 |

- 卡面存在与通用模型契约由 ContentContractSuite 全注册表扫描，逐卡不重复验证存在性；动画选择、时序与实例资源隔离仍保留专项检查。
- MinionSquadSuite 检查六种阵型、成员和各自 Buff 数值；DeploymentSkillSuite 统一检查七张多单位主动卡的存活筛选、旧批次/敌军隔离、队长转交、付款、次数和清场。
- 控制矩阵按实际 20Hz Tick 去重插入时间，每技能只运行一次无控制基准；不同控制、阵营、节点排列、来源和时序边界不能因断言文案相似而删除。
- 同一个脚本方法不得注册两次；同脚本不同入口可以分别声明场景，例如 maintenance_suite 与 maintenance_contracts。审计拒绝遗漏注册、重复入口和错误路径/分组。
- 普通运行只输出进度、失败和汇总；`-- --verbose-checks` 输出逐断言和边界 trace。人工场景不计作自动回归。

寻路夹具的来源见[接触模型](../docs/BATTLE_CONTACT_MODEL.md)。CPU 局部采样使用原始入口 `-- --profile-maintenance`，覆盖 32/64/128 单位，不等于整局 FPS 或设备认证。

## 自动联网终局验证

```sh
python3 tools/dev.py verify --network
python3 tools/dev.py verify --network-boundaries
python3 tools/dev.py verify --network-render
```

`--network` 自动选择空闲 UDP 端口（`--network-port` 可固定），启动服务器和两个客户端进程，比较会话、最终 Tick、胜负、完整实体/塔状态与终局音频事件；结果缺失、重复、不同步、脚本错误或超时均失败。`CLASH_TEST_DOUBLE_NEXUS=1` 仅由测试读取，用于同 Tick 双水晶平局。

`--network-boundaries` 加测版本/内容不一致、双方慢加载、加载中断线/超时、运行断线、返回菜单后同端口第二局与建筑同点部署。测试注入位于 fixtures；正式代码不读取用例参数。`--network-render` 保存 client0/client1 截图，仍需目视确认。

网络技能场景通过真实请求/权威接纳/完成后才终局（至少85Tick），保护退出在55..85Tick有效窗口观察；金币按实际终局Tick核对，并逐笔验证原收据退款。测试专用 `CLASH_TEST_TERMINAL_TICK=112` 可确定覆盖保护自然到期和第二次金币回复，值仅允许85..160；生产比赛不读取此开关。

三进程分别比较公共终态，并将两个客户端的金币、手牌、牌序、镜像历史和私有成长与对应服务器席位比较。边界模式还包含受损快照注入：丢弃1/3普通快照，交错延迟20/120ms，并将出牌发送延后80ms；不等同于真实WAN测试。服务器始终headless，实际渲染与录音只在两个客户端进行。重开使用真实返回菜单按钮，服务器自动重建会话，两端重新连接后允许交换阵营。

restart边界包含两次正式加载，外层测试预算为75秒（两次30秒生产加载期限加握手余量）；生产加载超时仍为30秒，会话/端口/清场断言照常执行。

手工长时观察使用 `tools/run_local_multiplayer.sh`，或一个服务器进程与两个客户端进程分别运行 `Godot --headless --path . -- --mode=server --auto-test` 与 `--mode=join --ip=127.0.0.1 --auto-test`。观察至少 12 秒后自行结束，不同时启动占同端口的两组服务器。本机链路不证明 WAN 条件。

已知未解决问题以[问题目录](../docs/issues/README.md)为准；旧报告不能代替本次运行。

### 当前网络覆盖

`session_suite` 同时验证有 UI、无 UI、销毁重建 UI 时主动提交、受理/拒绝/完成、费用退款、10 Tick、免费重施及编队转交不变，旧请求不能清新请求。它还负责身份/握手、私有四张手牌与下一张、版本/请求倒退、时钟样本去重/超时/重置、50–200ms自适应缓冲、按Tick播放及同Tick事件/快照次序、乱序插入、公开命令只读与复制隔离、准备通知不执行权威逻辑。

三进程通过正式 `play_card` / `use_active_skill` 提交，检查点击当帧输入反馈、10Tick命令缓冲、通知、取消、终局和清场；客户端不持有权威牌序或隐藏队列。impaired夹具加入技能请求、命令预告、可靠战斗信封、时钟响应延迟及快照丢弃/乱序，属于应用层故障注入，不能替代公网测试。渲染模式保留输入提示、下牌圆环、技能等待和终局截图，仍需目视检查。

## 实际渲染与音频

日常从 `Godot --path . -- --mode=workbench` 进入正式内容；专项场景统一在 [tools/demos](../tools/demos/README.md)，摄影配方在 [tools/capture](../tools/capture/README.md)。不再在 tests 保存重复演示场景。

常用入口：maintenance_preview（跨卡状态）、original_animation_review（连续动作及天使命中攻速）、workbench_preview/workbench_scenarios_preview（工作台）、combat_terminal_review（同刻死亡与水晶音频）。逐卡单机配方见工具索引与脚本，联网使用上面的三进程入口；不要求每次维护批量运行所有演示。

模型/特效变动必须看实际画面；音频变动必须实际试听。截图生成、cue 日志、短 WAV 播放器的自然 finished 检查都不能代替主观验收。结果写[改动记录](../docs/deliveries/README.md)，工作台不存验收勾选。

## Python 工具验证

```sh
python3 -m unittest discover -s tools/maintenance -p 'test_*.py'
python3 -m unittest discover -s tools/tests -p 'test_*.py'
```

两组按改动计划选用，`--full` 才统一执行全部安全 Python 门禁：前者验证审计和执行器的失败路径，后者验证通用素材工具的自包含逻辑。纯文档不附带这些工具测试。静态链接/注册审计不能代替受影响的机制回归。数值检查首批覆盖赛恩、凯隐、潘森的费用、生命、伤害、攻击间隔、实体部署锁定，以及主动费用、次数和冷却；未标记的数值、玩法解释和听感仍需人工核对。历史长篇测试说明保留在[归档](../docs/archive/2026-09-26/tests_README.md)。

LoadingAssetsSuite检查本场卡面缓存所有权、剑魔共享派生模板与活体动画/材质隔离，以及紧凑采样坏头/摘要格式拒收；完整数据逐位等价由受监督compact_sample_check另验。

MatchLoadingSuite以纯定义/源场景文本检查全部模型构造声明schema、旧储备与独立系统来源，以及无游戏模型的小型绘制身份。`python3 tools/maintenance/model_inventory_revision.py`补充开发复杂度/数量/循环门禁及账单；`--mode capabilities`仅六个同构模板逐一构造，`--mode scheduler`以虚拟时钟检查单步/有限退让/轮转/活跃额度和真实取消清理，`--mode compile-runtime`只编译，`--mode runtime`经真实MatchRuntime出牌/主动/被动/周期/亡语驱动有限消费，记录真实帧delta，补货依据已发生工作时钟，不手写事件代替权威链。各模式不自动串跑或重试；断言数不是场景数，具体覆盖、原2次缺货及调度修正后单次复验边界见[库存契约](../docs/MODEL_POOL_DEMAND.md)。真实单局计时另见[性能工具](../tools/performance/README.md#正常单局开局)。

SpellWarmupSuite验证法术JSON内部资源收集、非本局法术过滤、飞行/落地/命中样本准备、取消与节点清理，并确认无权威事件副作用；GPU准备须另跑实际渲染，headless不替代绘制验收。

## 表现重复工作回归

ProjectileSuite 内的 view 子检查覆盖内容代次、同帧前后读取、嵌套只读且无Object别名、旧snapshot副本隔离、逐渲染插值、延迟波/取消/死源独立/形态代次、clear/终局/新局，与原弹体套件复用场景。DependencyHeaderSuite 保留注册 ID，现用小夹具验证版本化清单缺失、损坏、错误schema/策略/身份/数组/路径显式拒绝，不再回退源JSON或支持旧依赖头。全库源/层/Shader策略内容身份及产物 SHA 由 `python3 tools/dev.py resources --check` 在相关 verify 计划中检查；微型 CLPS 长度/offset/数组边界和无源件隔离 PCK 合同用受保护 `python3 tools/maintenance/resource_contracts.py`。完整入口见[资源生成流程](../docs/RESOURCE_ARTIFACTS.md)。AnimationState 与 StructureRush 保留真实控制姿势及动作身份合同，不再断言已删除的私有恢复字段。

投影几何逐面合同、粒子出生索引多实例隔离和真实渲染像素/CPU对照见[性能工具](../tools/performance/README.md)。headless合同不替代Compatibility实际画面、预热或跨局清理检查。

`WorldOwnershipSuite`复用authority_battle，无模型、UI、音频、资源预热或端口。集中覆盖塔/水晶顺序与只读查询、正式出生Tick/双身份ID、动态建筑死亡/叠加占地、零血等待与真实移除、权威成长/副本落点、可靠销毁与快照补删、工作台清场/一次轻量重建，并复用既有依附效果投递小检查；只实例化性能World以确认计数入口/本地诊断快照，不运行基准。明确纳入既有authority-logic白名单，监督预算不变；不据此声明GUI/联网/性能验收。

`StrictContractSuite`使用无资源authority_battle与故障注入：检查旧代理删除、当前卡库合同、显式卡面收集、未知/缺失/错误类型资源传播、唯一快照解码/应用、完整6塔与14字段出生描述、缺出生记录/副本创建失败/本地缺塔的停止反馈。无UI、音频、模型、预热、端口或自动推进模拟；显式纳入现有authority-logic监督白名单，不修改预算。
