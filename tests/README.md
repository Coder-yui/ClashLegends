# 测试与验收

`tests/mechanics_check.gd` 是唯一 Godot 自动回归入口，`suite_catalog.json` 是套件 ID、脚本、方法、场景与领域的唯一注册表。默认执行全部领域；普通新卡自动进入全卡契约，仅独特机制需要专项用例。

## 按任务选入口

| 验证类型 | 常用入口 | 证明范围 |
| --- | --- | --- |
| 文档、路径、注册与资源引用 | `python3 tools/maintenance/audit_project.py` | 静态完整性；不证明运行行为或资源听感 |
| 机制/测试代码改动 | `python3 tools/dev.py verify` | 审计、工具故障夹具、导入、数值标记、全部机制及差异检查 |
| 定位单领域/单卡 | `verify --group status` / `verify --suite OrnnSuite`（均通过tools/dev.py） | 只验证所选范围，最终全量仍用上一行 |
| 网络协议、快照、生命周期 | `python3 tools/dev.py verify --network` | 全量加本机双进程终局一致性；边界故障另加`--network-boundaries` |
| 模型、UI、动画、音频 | 工作台及[专项场景](../tools/demos/README.md) | 实际渲染/试听，需人工验收；headless通过不能替代 |
| 局部性能 | Godot机制入口追加`-- --profile-maintenance` | 固定32/64/128单位CPU采样；需同条件前后比较，不当成FPS或正确性门槛 |

历史一次性配方与证据保留原路径，按对应交付复现，不加入默认测试或当作当前通过证明。注册ID保留稳定命令接口，不为大小写统一而改名。当前入口清单通过 `verify --list-suites` 查询，数量以catalog与本次结构化结果为准。

金克丝专项 `--suite JinxSuite` 覆盖换枪次数/冷却、在途弹体、空地溅射、机枪三层、建筑/防御塔/水晶助攻边界、命中后自然到期/衰血致死及超时排除、移动切枪下肢同相位混合/结束不重启及武器伸缩保形、凝滞、同批互杀与快照；6秒叠层/刷新、120Tick到期、躯干后方速度线出生分布、爆炸45像素外沿及层数/剩余时间网络往返。

## 基本检查

```sh
python3 tools/dev.py verify
```

依次执行项目审计、验证工具故障夹具、Godot 导入、编译卡牌数值导出与手册核对、机制回归与 `git diff --check`，失败即停。每步默认超时 600 秒并清理进程组；通过 `--godot /绝对路径/Godot`、`--timeout 900`、`--output /新的目录` 指定环境。`python3 tools/dev.py doctor` 查询本机依赖。

证据默认在 `ClashLegends-开发素材库/04-中间产物/构建与验证/verification/<时间戳>/`。result.json 记录提交、脏工作区、文件摘要、引擎版本、命令、耗时与结果；运行中工作区变化判失败。输出目录必须尚不存在。

机制通过要求：正常退出、无脚本/资源错误、唯一结构化结果、所选套件全部且仅完成一次、失败数为零，以及最终“全部通过”。断言数不是门槛。结构化结果包含每套件耗时、检查数和失败数，方便定位昂贵用例；不以单次耗时证明性能改善。

单步定位：

```sh
python3 tools/maintenance/audit_project.py
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script tests/mechanics_check.gd
git diff --check
```

## 独立套件与顺序隔离

```sh
python3 tools/dev.py verify --list-suites
python3 tools/dev.py verify --group combat
python3 tools/dev.py verify --group deployment --suite MinionSquadSuite
python3 tools/dev.py verify --reverse-suites
```

重复 `--group` 或 `--suite` 取并集，按注册顺序只执行一次；未知名称报错。选跑只证明该范围。原始 Godot 入口支持 `-- --list-suites`、`-- --suite=ProjectileSuite` 与 `-- --reverse-suites`；领域选择由 Python 执行器展开。

每套件固定种子 12345，按需新建菜单/对局，关闭自动主循环、AI 与常规兵线；结束释放场景，检查 combatants 和根节点无遗留。套件内部多个用例仍须清理自己的临时状态。跨套件不能复用可变场景来换取速度。

## 分类与覆盖所有者

| 目录 / group | 负责范围 |
| --- | --- |
| `suites/contracts/` / contracts | 四域、类型、递归只读、全卡资源/包装/动画/卡面、时钟与所有权合同 |
| `suites/combat/` / combat | 数值、索敌、弹体、批次公平性、兵线建筑、自然到期、接触寻路、普通击退 |
| `suites/deployment/` / deployment | 部署区域/建筑落点、付款、编队资格转交与批次隔离 |
| `suites/status/` / status | 通用主动时序、控制前后边界、盾层、限时形态 |
| `suites/presentation/` / presentation | 动作、材质、插值、共享特效、声音归属与终局播放器生命周期 |
| `suites/ui/` / ui | 备战、工作台交互、经典场景 |
| `suites/network/` / network | 单进程协议/会话/副本/终态；双进程脚本由网络模式单独调度 |
| `suites/cards/` / cards | 逐卡特有规则、数值、动作与特殊效果；六种普通小兵编队集中在 MinionSquadSuite |
| `suites/battle_suite.gd`、`suite_utils.gd` | 共享绑定、断言、固定Tick、既有模型代理查询与内容夹具；不单独注册 |
| `fixtures/` | 网络场景、固定牌序辅助及原始寻路输入 |

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

`--network` 自动选择空闲 UDP 端口（`--network-port` 可固定），启动主客进程，比较会话、最终 Tick、胜负、完整实体/塔状态与终局音频事件；结果缺失、重复、不同步、脚本错误或超时均失败。`CLASH_TEST_DOUBLE_NEXUS=1` 仅由测试读取，用于同 Tick 双水晶平局。

`--network-boundaries` 加测版本/内容不一致、双方慢加载、加载中断线/超时、运行断线、返回菜单后同端口第二局与建筑同点部署。测试注入位于 fixtures；正式代码不读取用例参数。`--network-render` 保存 host/client 截图，仍需目视确认。

restart边界包含两次正式加载，外层测试预算为75秒（两次30秒生产加载期限加握手余量）；生产加载超时仍为30秒，会话/端口/清场断言照常执行。

手工长时观察使用 `tools/run_local_multiplayer.sh`，或两个进程分别运行 `Godot --headless --path . -- --mode=host --auto-test` 与 `--mode=join --ip=127.0.0.1 --auto-test`。观察至少 12 秒后自行结束，不同时启动占同端口的两组主机。本机链路不证明 WAN 条件。

已知未解决问题以[问题目录](../docs/issues/README.md)为准；旧报告不能代替本次运行。

## 实际渲染与音频

日常从 `Godot --path . -- --mode=workbench` 进入正式内容；专项场景统一在 [tools/demos](../tools/demos/README.md)，摄影配方在 [tools/capture](../tools/capture/README.md)。不再在 tests 保存重复演示场景。

常用入口：maintenance_preview（跨卡状态）、original_animation_review（连续动作及天使命中攻速）、workbench_preview/workbench_scenarios_preview（工作台）、combat_terminal_review（同刻死亡与水晶音频）。逐卡配方和 host/join 参数见工具索引与脚本；不要求每次维护批量运行所有演示。

模型/特效变动必须看实际画面；音频变动必须实际试听。截图生成、cue 日志、短 WAV 播放器的自然 finished 检查都不能代替主观验收。结果写[交付文档](../docs/deliveries/README.md)，工作台不存验收勾选。

## Python 工具验证

```sh
python3 -m unittest discover -s tools/maintenance -p 'test_*.py'
python3 -m unittest discover -s tools/tests -p 'test_*.py'
```

前者验证审计和执行器的失败路径，由 verify 自动执行；后者用于通用素材工具改动。静态链接/注册审计不能代替机制回归。数值检查首批覆盖赛恩、凯隐、潘森的费用、生命、伤害、攻击间隔、实体部署锁定，以及主动费用、次数和冷却；未标记的数值、玩法解释和听感仍需人工核对。历史长篇测试说明保留在[归档](../docs/archive/2026-09-26/tests_README.md)。
