# 测试与验收

`tests/mechanics_check.gd` 是唯一 Godot 自动回归入口，`suite_catalog.json` 是套件 ID、脚本、方法、场景与领域的唯一注册表。默认执行全部领域；普通新卡自动进入全卡契约，仅独特机制需要专项用例。

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
| `suites/battle_suite.gd`、`suite_utils.gd` | 共享绑定、断言、固定 Tick 与内容夹具；不单独注册 |
| `fixtures/` | 网络场景、固定牌序辅助及原始寻路输入 |

新增用例先找所有者，遵循以下去重边界：

奥恩的 OrnnSuite 覆盖永久全场普攻增幅的时序/排序/不重复、伤害取整、固定速度地形冲锋、阻挡建筑免路径伤害及撞停后的范围伤害与眩晕。

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

LuluSuite覆盖部署首批/7秒周期、左右生成、目标优先级/排除、固定生命增量、体型、换形、不可重复及空目标/目标消失退款。网络生命周期套件覆盖成长字段、非法载荷和重复快照。

CombatActivitySuite覆盖公共战斗事实、纯护盾承伤归属、硬控/减益阻止空闲、瑟提1秒与图奇2秒消费、位移阶段眩晕/击退取消及凯隐停止后普通技能保护、同批路径伤害保留；原逐卡与控制矩阵继续覆盖正常技能及独立结果。

ForcedDisplacementSuite覆盖两阶段落点、保速延长/缩短锁、河流与斜线预算、动态建筑与凝滞占位、体型/空地变化、无解重试、批次交叉接管，以及双方先锋实际撞塔六虫和女皇死亡八鱼的真实位移。动画与声音所有权继续由表现套件负责。
