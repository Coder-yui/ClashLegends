# 测试与验收

`tests/mechanics_check.gd` 是唯一 Godot 自动回归入口，直接编排领域套件，特殊卡规则在 `suites/cards/`。普通新卡自动进入 CardDB 与全卡场景/动画/卡面契约，不新增独立测试入口。

## 基本检查

```sh
python3 tools/maintenance/audit_project.py
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script tests/mechanics_check.gd
git diff --check
```

本机 Godot 为 `/Applications/Godot.app/Contents/MacOS/Godot`。必须看到最终“全部通过”并检查 `SCRIPT ERROR`、资源错误；退出码不能单独证明测试执行完成。回归结束先释放场景，再给音频线程短暂清理时间，避免高速 headless 退出时音频流仍被混音线程持有。

| 领域 | 套件与边界 |
| --- | --- |
| 定义与内容 | card_db_validation、content_contract、maintenance：四域、递归只读、资源、召唤引用、全卡包装与动画 |
| 备战/展示 | deck_builder：选择、槽位与详情；CardDetails 只读数据供 UI 和相关卡牌断言共用 |
| 部署与对战 | arena_deployment、combat_targeting、projectile、building_minion：资格、命中、弹体、兵线、建筑与男爵之力 |
| 时钟/控制/动作 | maintenance、active_skill、animation_state：全部 Tick、控制组合、攻击和施法窗口、生命周期 |
| 接触与寻路 | navigation_collision：44 组原始搜索夹具、圆柱碰撞、持续推行、限幅、无残留动量 |
| 数值 | numeric_system 及逐卡用例：整数生命/伤害、实际掉血吸血、持续余量、精度校验 |
| 音频 | audio_presentation：真实事件、双方/形态来源、去重、独占弹体/区域/建筑音轨、暂停/恢复/清场 |
| 工作台 | workbench_suite：素材隔离、选择、试听、记录、资源技能；由统一入口在 active_skill 后独立调用 |
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
| `maintenance_preview` | 双方攻击、控制、变形、死亡、恢复；`/tmp/clash-maintenance-render/` |
| `workbench_preview`、`workbench_scenarios_preview` | 四页交互与四种经典场景、红方镜像 |
| `original_animation_review` | 全部非法术卡、双方/形态；`-- --cards=gwen,xin --all-exits --transition-frames`；`--validate-only` 只检查表现路径 |
| `sett_animation_preview` | 四拳、多倍率、W 出口、死亡；可加 `--fixed-fps 30`；`/tmp/clash-sett-animation/` |
| `card_playtest_fixes_preview`、`contact_preview` | 首击/追击、边界与接触问题复现 |
| `gwen_passive_preview` | 剪切与被动双阵营画面、主混音；`/tmp/clash-gwen-passive/` |
| `ashe_volley_collision_preview` | 万箭齐发阻挡、真实碰撞与提示 |
| `gnar_launch_audio_preview` | 独占发射尾音；支持 `-- --mode=host` / `--mode=join`；`/tmp/clash-gnar-launch/` |
| `xin_sweep_effect_review`、`demo_xin_sweep.tscn` | 正式工作台横扫各阶段；交互式横扫演示 |
| `apex_audio_review` | 炮台创建、引擎、普攻和穿透激光；支持 host/join；`/tmp/clash-apex-audio/` |
| `twisted_fate_deploy_review` | 26+9 Tick 部署与单次原声前段，支持 host/join；`/tmp/clash-tf-deploy-175/` |
| `sun_disc_tombstone_review` | 圆盘双攻击、护盾扩散波、消失及墓碑持续声 |
| `event_audio_review`、`event_audio_network_review` | 范围护盾、兵线、塔/水晶事件；后者支持 headless host/join |
| `match_audio_review`、`nexus_audio_lifecycle_review` | 比赛播报；水晶出生/待机交叉淡化/死亡与原生深井显示 |
| `baron_minion_preview`、`baron_projectile_preview` | 四兵双方八阶段；强化炮弹逐帧截图 |
| `baron_minion_network` | host/join 八单位 on/off、强化炮弹 Snapshot 和出膛/命中事件 |
| `numeric_review` | 卡牌详情数值 UI；`/tmp/clash-numeric-review/` |
| `card_audio_batch_demo` | 正式工作台事件录音/截图；`-- --network` 做网络音频冒烟 |
| `ashe_audio_demo`、`garen_audio_demo`、`missfortune_audio_demo`、`sustained_audio_demo` | 分卡或持续音场景，用于人工听感和生命周期复核 |
| `stage_debris_demo.tscn`、`structure_showcase` | 建筑破碎、废墟与结构展示；参数见相邻脚本及说明 |

专项脚本保留有价值的场景配方，不等于每次维护都必须全部运行。模型/特效变动需要实际画面，音频变动需要实际试听；录音生成或 cue 日志只证明可记录/已派发，不能自动写“听感通过”。当前用户验收批次与未完成设备检查见 [开发状态](../docs/DEV_PLAN.md)。

Python 审计工具自身的边界验证：`python3 -m unittest discover -s tools/maintenance -p 'test_*.py'`。它验证链接/注册/排除规则，不替代 Godot 机制回归。

## 测试维护约定

共享绑定、断言转发与固定 Tick 推进集中在 `suites/battle_suite.gd`；它不是可单独运行的套件。弹体套件统一提供 `run()`，入口不再逐个调用私有用例。默认输出套件进度、失败详情与总断言数；需要逐断言日志时追加 `-- --verbose-checks`。

全卡契约集中扫描注册表，普通卡不重复建立资源存在测试；专项套件保留独特机制、时序和动画选择断言。演示/截图/人工试听脚本留在 tools，不计作自动测试通过。单位手册的链接和注册覆盖由项目审计检查；数值和说明需人工核对当前实现，历史归档保留当时记录。
