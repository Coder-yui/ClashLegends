# 测试与验收

`tests/mechanics_check.gd` 是唯一 Godot 自动回归入口，直接编排领域套件，特殊卡规则在 `suites/cards/`。普通新卡自动进入 CardDB 与全卡场景/动画/卡面契约，不新增独立测试入口。

## 基本检查

推荐使用 `python3 tools/dev.py verify`（等价于 `python3 tools/verify.py`）。入口依次执行审计、验证工具故障夹具、Godot 导入、机制回归与 `git diff --check`，任一步失败即停止。每步默认超时 600 秒，超时清理进程组；可用 `--godot /绝对路径/Godot`、`--timeout 900` 和 `--output /新的输出目录` 指定环境。

证据默认保存到 `ClashLegends-开发素材库/04-中间产物/构建与验证/verification/<时间戳>/`：各步骤完整日志与 `result.json` 包含提交 SHA、脏工作区状态、受 Git 管理及未忽略新文件的内容摘要、引擎精确版本、命令、耗时及结果。运行期间内容变化会判失败，需要在稳定工作区重跑。输出目录必须尚不存在，避免覆盖证据；推荐保持在已忽略的 `ClashLegends-开发素材库/04-中间产物/构建与验证/` 下。目录内结果仅代表该次实际工作区，不能当作纯提交或人工验收结论。

机制通过要求：进程正常退出、无脚本/资源错误、唯一结构化结果、当前编排中的全部套件返回且失败数为零、存在中文最终成功汇总。断言数只记录，不固定历史门槛。下面的单步命令仍可用于定位问题：

```sh
python3 tools/maintenance/audit_project.py
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script tests/mechanics_check.gd
git diff --check
```

通过 `python3 tools/dev.py doctor` 查询本机 Godot，或用 verify 的 `--godot` 指定。必须看到最终“全部通过”并检查 `SCRIPT ERROR`、资源错误；退出码不能单独证明测试执行完成。回归结束先释放场景，再给音频线程短暂清理时间，避免高速 headless 退出时音频流仍被混音线程持有。

| 领域 | 套件与边界 |
| --- | --- |
| 定义与内容 | card_db_validation、content_contract、maintenance：四域、递归只读、资源、召唤引用、全卡包装与动画 |
| 备战/展示 | deck_builder：选择、槽位与详情；CardDetails 只读数据供 UI 和相关卡牌断言共用 |
| 部署与对战 | arena_deployment、combat_targeting、projectile、building_minion：资格、命中、弹体、兵线、建筑与男爵之力 |
| 时钟/控制/动作 | maintenance、active_skill、animation_state：全部 Tick、控制组合、攻击和施法窗口、生命周期 |
| 接触与寻路 | navigation_collision：44 组原始搜索夹具、圆柱碰撞、持续推行、限幅、无残留动量 |
| 数值 | numeric_system 及逐卡用例：整数生命/伤害、实际掉血吸血、持续余量、精度校验 |
| 音频 | audio_presentation：真实事件、双方/形态来源、去重、独占弹体/区域/建筑音轨、暂停/恢复/清场 |
| 工作台 | workbench_suite：素材隔离、选择、试听、资源技能；由统一入口在 active_skill 后独立调用 |
| 网络生命周期 | network_lifecycle：真实编码、乱序/丢包、未知实体重建、重复事件、旧会话与同 Tick 屏障 |
| 经典场景 | workbench_scenario：重建、塔/导航恢复、双阵营镜像、过桥、法术与正式模式隔离 |
| 特殊卡 | suites/cards：独特玩法和连续动画；腕豪裁剪/拳序、格温逐剪、凤凰复生等 |

命令排程查 `main._commands`，比赛状态查 `main._match_rules`，普攻阶段查 `unit.attack_timeline`，控制查 `unit.control`。回归直接推进权威入口，不用渲染帧触发胜负。寻路夹具的证据和再生范围见 [接触模型](../docs/BATTLE_CONTACT_MODEL.md)。

CPU 局部采样：`Godot --headless --path . --script tests/mechanics_check.gd -- --profile-maintenance`。采样 32/64/128 单位的索敌、移动/碰撞和快照压缩，不等于整局 FPS、手机或广域网认证。

## 本机网络冒烟

两个进程至少同时运行 12 秒，检查启动、生成、动作、形态、弹体和来源事件日志；交互式窗口可用 `tools/run_local_multiplayer.sh`。

```sh
Godot --headless --path . -- --mode=host --auto-test
Godot --headless --path . -- --mode=join --ip=127.0.0.1 --auto-test
```

这些进程不会自动退出，由操作者在收集证据后结束。测试固定端口不能同时运行两组 host。此检查证明本机主客机链路，不覆盖真实 WAN 条件。

## 实际渲染与音频

统一执行方式：`Godot --path . --script tools/demos/<脚本>.gd`，省略 `--headless`。日常交互使用 `Godot --path . -- --mode=workbench`。

| 脚本（tools/demos/） | 检查范围 / 主要输出 |
| --- | --- |
| `maintenance_preview` | 双方攻击、控制、变形、死亡、恢复；`ClashLegends-开发素材库/04-中间产物/预览与验证/clash-maintenance-render/` |
| `workbench_preview`、`workbench_scenarios_preview` | 三页交互与四种经典场景、红方镜像 |
| `original_animation_review` | 全部非法术卡、双方/形态；`-- --cards=gwen,xin --all-exits --transition-frames`；`--validate-only` 只检查表现路径 |
| `sett_animation_preview` | 四拳、多倍率、W 出口、死亡；可加 `--fixed-fps 30`；`ClashLegends-开发素材库/04-中间产物/预览与验证/clash-sett-animation/` |
| `card_playtest_fixes_preview`、`contact_preview` | 首击/追击、边界与接触问题复现；`contact_preview -- --knockback` 检查普通击退撞岸与实体接触 |
| `gwen_passive_preview` | 剪切与被动双阵营画面、主混音；`ClashLegends-开发素材库/04-中间产物/预览与验证/clash-gwen-passive/` |
| `ashe_volley_collision_preview` | 万箭齐发阻挡、真实碰撞与提示 |
| `gnar_launch_audio_preview` | 独占发射尾音；支持 `-- --mode=host` / `--mode=join`；`ClashLegends-开发素材库/04-中间产物/预览与验证/clash-gnar-launch/` |
| `xin_sweep_effect_review`、`demo_xin_sweep.tscn` | 正式工作台横扫各阶段；交互式横扫演示 |
| `apex_audio_review` | 炮台创建、引擎、普攻和穿透激光；支持 host/join；`ClashLegends-开发素材库/04-中间产物/预览与验证/clash-apex-audio/` |
| `twisted_fate_deploy_review` | 26+9 Tick 部署与单次原声前段，支持 host/join；`ClashLegends-开发素材库/04-中间产物/预览与验证/clash-tf-deploy-175/` |
| `sun_disc_tombstone_review` | 圆盘双攻击、护盾扩散波、消失及墓碑持续声 |
| `event_audio_review`、`event_audio_network_review` | 范围护盾、兵线、塔/水晶事件；后者支持 headless host/join |
| `match_audio_review`、`nexus_audio_lifecycle_review` | 比赛播报；水晶出生/待机交叉淡化/死亡与原生深井显示 |
| `baron_minion_preview`、`baron_projectile_preview` | 四兵双方八阶段；强化炮弹逐帧截图 |
| `baron_minion_network` | host/join 八单位 on/off、强化炮弹 Snapshot 和出膛/命中事件 |
| `numeric_review` | 卡牌详情数值 UI；`ClashLegends-开发素材库/04-中间产物/预览与验证/clash-numeric-review/` |
| `card_audio_batch_demo` | 正式工作台事件录音/截图；`-- --network` 做网络音频冒烟 |
| `ashe_audio_demo`、`garen_audio_demo`、`missfortune_audio_demo`、`sustained_audio_demo` | 分卡或持续音场景，用于人工听感和生命周期复核 |
| `stage_debris_demo.tscn`、`structure_showcase` | 建筑破碎、废墟与结构展示；参数见相邻脚本及说明 |

专项脚本保留有价值的场景配方，不等于每次维护都必须全部运行。模型/特效变动需要实际画面，音频变动需要实际试听；录音生成或 cue 日志只证明可记录/已派发，不能自动写“听感通过”。当前用户验收批次与未完成设备检查见 [开发状态](../docs/DEV_PLAN.md)。

Python 审计工具自身的边界验证：`python3 -m unittest discover -s tools/maintenance -p 'test_*.py'`。它验证链接/注册/排除规则，不替代 Godot 机制回归。

## 测试维护约定

共享绑定、断言转发与固定 Tick 推进集中在 `suites/battle_suite.gd`；它不是可单独运行的套件。弹体套件统一提供 `run()`，入口不再逐个调用私有用例。默认输出套件进度、失败详情与总断言数；需要逐断言日志时追加 `-- --verbose-checks`。

全卡契约集中扫描注册表，普通卡不重复建立资源存在测试；专项套件保留独特机制、时序和动画选择断言。演示/截图/人工试听脚本留在 tools，不计作自动测试通过。单位手册的链接和注册覆盖由项目审计检查；数值和说明需人工核对当前实现，历史归档保留当时记录。

## 自动联网终局验证

`python3 tools/verify.py --network` 在完整验证后启动独立主机与客户端，自动选择本机空闲 UDP 端口，比较可靠终态的会话、最终 Tick、胜负、塔血量与完整单位集合。缺结果、重复结果、脚本错误、状态不一致、子进程失败或超时均判失败并清理进程。`--network-port 39152` 可固定端口。

`python3 tools/verify.py --network-render` 使用实际渲染运行同一场景，并在验证目录保存 `host.png`、`client.png`；图片仍需目视检查。音频停止的自动断言不等同于人工听感确认。终局白盒用例在 `terminal_state_suite.gd`，双进程用例在 `network_integration_suite.gd`。

`python3 tools/verify.py --network-boundaries` 额外运行版本不一致、内容不一致、慢加载、中途断线和返回按钮重载后同端口第二局。正常联网用例同时插入第三个 ENet 连接、重复出牌、旧会话技能与局中重复注册。测试注入只存在于 `tests/fixtures/network_boundary_main.gd`；正式代码不读取这些测试场景参数。

`building_placement_suite.gd` 覆盖等待不占位、分时生成、最近合法位置、费用和手牌、额外预部署、全场无位置重试及最终塔墟加成。`--network-boundaries` 包含客户端连续提交同位置墓碑/太阳圆盘：双方均有两栋不重叠建筑，共扣 7 金币，两张牌均正常轮换。

`CardDBValidationSuite` 在原始定义层检查四域及技能/形态合并，拒绝错域和同名覆盖；还逐一破坏艾希、纳尔、格温的配置叶子，验证完整字段诊断。统一验证器同时检查日志没有 `SCRIPT ERROR`，避免校验器异常被当成正常拒绝。

## 独立套件与顺序隔离

`tests/suite_catalog.json` 是套件 id、脚本、调用入口与场景需求的唯一注册表。每套件固定随机种子 12345，按需新建菜单或本地对局；关闭自动主循环、AI 与常规兵线，结束销毁场景并检查战斗对象及根节点无遗留。共享 CardDB 定义保持递归只读，资源缓存不充当战斗状态。套件内部的白箱检查仍保留。

- 查看名称：`Godot --headless --path . --script tests/mechanics_check.gd -- --list-suites`
- 单独验证：`python3 tools/verify.py --suite ProjectileSuite --timeout 120`
- 多项选择：重复 `--suite`；每个所选套件仍独立场景。
- 反序检查：`python3 tools/verify.py --reverse-suites --timeout 180`

Godot 原始入口使用 `-- --suite=ProjectileSuite`，未知名称退出 2；统一执行器核对所选套件完成清单，不能用选跑结果冒充全量通过。默认不加筛选仍运行全部套件，联网验证维持独立双进程入口。


`CombatBatchSuite` 覆盖正常连续镜像互换、阵营/创建/节点/集合排列、真实早一 Tick、三轮追加刀、取消前摇、攻速/免疫变化、硬控暂停、施法/击退、逐刀致盲、护盾/吸血归属、死亡生成与持续/技能阶段互换。日志 `FAIRNESS_TRACE` / `EXTRA_FAIRNESS_TRACE` 记录提交与死亡阶段。

`TerminalAudioSuite` 使用短 WAV 替代混音输入，验证真实播放器自然 finished、双轨等待、实例复用、重复/跨局回调和缺资源兜底；不作为听感认证。双进程 `--network` 还等待本地真实水晶音轨，验证本地胜败播报；使用 `CLASH_TEST_DOUBLE_NEXUS=1 python3 tools/verify.py --network` 验证双向真实弹体在同 Tick 摧毁两水晶和主客平局一致（环境开关只由测试套件读取）。

实际画面/混音复核：`Godot --path . --script tools/demos/combat_terminal_review.gd`，输出 `ClashLegends-开发素材库/04-中间产物/预览与验证/clash-combat-terminal/` 的镜像死亡、第三/六/九次连击、立即终局截图及 `explosion-victory.wav`。需另行试听录音，日志不能替代听感。


`BuildingExpiryBoundarySuite` 从正常索敌前摇推进到建筑到期 Tick，交换阵营、出生、节点和集合排列，并比较攻击段、间隔、目标与收益；另测衰减、部署/控制、召唤边界、失效请求和全盾合法命中。`KnockbackBoundarySuite` 检查真实位移、接管速度/方向/时长、暂停恢复及固定事件身份的逆序收集。两者通过统一入口 `--suite=...` 可独立执行；不是工作台验收记录。

`ShurimaGuardSuite` 覆盖六人横排、贴边整体平移、同次部署筛选、逐人破盾/清除/死亡/自然到期恢复、其他护盾隔离、队长死亡转交和技能2费限1次。

`StructureRushSuite`覆盖建筑冲撞、免控与准备重置、桥面允许/水域禁止、绕行后启动、路径单次伤害和侧推、当前生命代价、六只蠕虫及180°技能。实机配方：`tools/demos/structure_rush_review.gd`，生成双方阶段截图与混音录音。

2026-09-16性能准备回归：DeckBuilderSuite覆盖双方先锋六只、五轮60次模型领取/回收、包装重置与加载中退出；PresentationSuite验证有限材质复用、编译曲线/概率表及粒子依赖范围；StructureRushSuite验证失败搜索冷却、换目标、建筑变化与恢复。`--network-boundaries`另含slow_host、load_disconnect和load_timeout，超时用例只在测试中推进截止时间，实际清理由正式入口执行。

`DeploymentSkillSuite` 覆盖七张多单位主动卡的工作台成员死亡/释放、批次与阵营隔离、全灭禁止回退、正式请求期间连续转交、费用次数保留和延迟效果的存活筛选。`network_lifecycle_suite` 验证转交快照按编队来源卡恢复技能。

`StatusBoundarySuite` 从正式请求覆盖解冻待变形、退款、转换结束边界、技能各段/完成回血精确 Tick、凤凰蛋排列互换、旧弹体及冻结朝向。`network_lifecycle_suite` 覆盖六位权限校验与首次同时收到技能/眩晕；双端终态另比较权限、身体方向及技能剩余次数。实际渲染复用 `maintenance_preview.gd -- --status-boundaries --cards=sett,gnar,gwen,aurelionsol,garen,anivia_egg`。

维护审计同时检查本地章节锚点、导航可达性、默认必读不能指向历史、显式当前协议事实、卡牌/形态文档映射；包括历史区域链接。导航声明在 [navigation.json](../docs/navigation.json)，审计夹具通过 `python3 -m unittest discover -s tools/maintenance -p 'test_*.py'` 执行。
