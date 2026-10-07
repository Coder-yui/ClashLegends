# 游戏运行代码导航

返回 [项目入口](../README.md)。权威子系统按[战斗目录导航](battle/README.md)定位。离线提取、转换、摄影与试听工具在 [tools](../tools/README.md)；这里仅放游戏运行和工作台代码。

| 位置 | 职责与复用方式 |
| --- | --- |
| `main.gd` | 比赛生命周期和编排；新机制优先放对应领域 |
| `battle/` | 固定时钟、规则、移动、攻击时间线、弹体、快照和战场服务 |
| `unit.gd`、`tower.gd` | 通用战斗实体；普通新卡复用 Unit，不另建英雄子类 |
| `data/` | 卡牌定义、注册、字段校验；每卡按 gameplay / visual / card_art / audio 分域 |
| `presentation/` | 只读权威状态的模型、动画、特效表现 |
| `audio/` | 只读表现事件的音频播放与共用播放器创建 |
| `ui/` | 主界面、备战和开发工作台 |
| `ui/workbench/` | 工作台模型预览、实战配方与正式音频清单；`audio_catalog.gd` 只展开配置，`model_preview.gd` 供独立摄影复用 |

新增卡牌先读 [新卡清单](../docs/NEW_CARD_CHECKLIST.md)；结构修改读 [维护架构](../docs/MAINTENANCE_ARCHITECTURE.md)。共享组件留在所属领域，离线工具通过公开入口复用，避免复制整套摄影棚或把工具逻辑塞入 Main。

`diagnostics/release_smoke.gd` 是仅由专用命令行参数启动的发布包探针，验证真实开局、命令和终局；不进入正常菜单流程。

业务所有者：`battle/command_schedule.gd` 管理排程，`active_skill_roster.gd` 管理技能资格，`card_cycle.gd` 管理牌序，`deployment_rules.gd` 管理部署判断，`knockback_state.gd` 管理击退轨迹；工作台会话在 `ui/workbench/session.gd`。Main 保留装配、场景与 UI/RPC。

工作台组件按职责划分：`session` 持有会话，`card_catalog` 展开正式目录，`card_library` 搜索与快捷栏，`card_info` 只读详情，`animation_picker` 动作列表，`desktop_layout` 窗口与观察变换。主 UI 负责装配，不将状态回写卡牌定义。

独立服务器通过 `--mode=server` 启动，不占玩家席位。`battle/battle_simulation.gd` 是服务器、单机、工作台共用的固定阶段编排；`battle/match_session.gd` 管理两席玩家身份与连接映射。客户端只驱动输入和表现；精确协议见[联网契约](../docs/reference/NETWORK_PROTOCOL.md)。


联机时间与操作：`battle/network_clock.gd`校准服务器时钟，`battle/network_command_state.gd`保存出牌/技能的公开准备与完成身份，`battle/network_playback.gd`按同一Tick时间轴应用快照/表现事件。只有CommandSchedule/BattleSimulation执行真实命令，客户端时间轴不能驱动战斗规则。
