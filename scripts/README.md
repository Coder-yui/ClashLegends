# 游戏运行代码导航

返回 [项目入口](../README.md)。先用[整体设计地图](../docs/MAINTENANCE_ARCHITECTURE.md#整体设计地图)理解游戏循环与分层，再按本页定位文件；权威子系统细分见[战斗目录导航](battle/README.md)。离线提取、转换、摄影与试听工具在 [tools](../tools/README.md)；这里仅放游戏运行和工作台代码。

| 位置 | 职责与复用方式 |
| --- | --- |
| `main.gd` | 比赛生命周期和编排；新机制优先放对应领域 |
| `battle/` | 固定时钟、规则、移动、攻击时间线、弹体、快照和战场服务 |
| `unit.gd`、`tower.gd` | 通用战斗实体；普通新卡复用 Unit，不另建英雄子类 |
| `data/` | 卡牌定义、注册、字段校验；每卡按 gameplay / visual / card_art / audio 分域 |
| `presentation/` | 只读权威状态的模型、动画、特效表现 |
| `audio/` | 只读表现事件的音频播放与共用播放器创建 |
| `ui/` | 主界面、备战和开发工作台 |
| `ui/battle_layout.gd` | 对战窗口、等比取景与 HUD 的统一计算；输入逆变换使用同一画布，不缩放权威坐标 |
| `ui/workbench/` | 工作台模型预览、实战配方与正式音频清单；`audio_catalog.gd` 只展开配置，`model_preview.gd` 供独立摄影复用 |

新增卡牌先读 [新卡清单](../docs/NEW_CARD_CHECKLIST.md)；结构修改读 [维护架构](../docs/MAINTENANCE_ARCHITECTURE.md)。共享组件留在所属领域，离线工具通过公开入口复用，避免复制整套摄影棚或把工具逻辑塞入 Main。

## 按一条运行路径定位

| 要追踪什么 | 先看这些入口 |
| --- | --- |
| 备战到开局 | `ui/deck_builder.gd` → Main 的开局/加载流程 → `battle/match_session.gd`、`presentation/match_resource_plan.gd`、`presentation/match_resources.gd` |
| 一次卡牌或主动操作 | Main 的 `play_card` / `use_active_skill` → `battle/command_schedule.gd`、`command_payment.gd`、`active_skill_roster.gd` |
| 一个权威 Tick | `battle/fixed_step_clock.gd` → `battle/battle_simulation.gd` → 对应状态/移动/命中系统；[阶段表](../docs/MAINTENANCE_ARCHITECTURE.md#一个权威-tick-的阶段)解释顺序 |
| 一张卡生成什么 | `data/cards/<id>.gd` → CardDB 的 `get_card` / `deployment_plan` / `get_unit_stats` → Main 生成入口与 `battle/unit_spawn_request.gd` |
| 主机状态怎样到客户端 | `battle/network_snapshot_system.gd` → `network_playback.gd` → Main 副本应用与 `network_entity_lifecycle.gd`；字段只查[联网契约](../docs/reference/NETWORK_PROTOCOL.md) |
| 一个画面或声音 | `presentation/unit_presentation_state.gd`、`battle/projectile_system.gd` 的只读视图或真实事件 → `presentation/` / `audio/` 的消费者 |

共享定义只回答配置，实例与排程保存可变状态，表现投影只供读取。Main 仍含部分领域协调与部署几何；这张路径表说明当前入口，不表示所有业务已从 Main 抽离。

`diagnostics/release_smoke.gd` 是仅由专用命令行参数启动的发布包探针，验证真实开局、命令和终局；不进入正常菜单流程。

业务所有者：`battle/command_schedule.gd` 管理排程，`active_skill_roster.gd` 管理技能资格，`card_cycle.gd` 管理牌序，`deployment_rules.gd` 管理部署判断，`knockback_state.gd` 管理击退轨迹；工作台会话在 `ui/workbench/session.gd`。Main 保留装配、场景与 UI/RPC。

工作台组件按职责划分：`session` 持有会话，`card_catalog` 展开正式目录，`card_library` 搜索与快捷栏，`card_info` 只读详情，`animation_picker` 动作列表，`desktop_layout` 窗口与观察变换。主 UI 负责装配，不将状态回写卡牌定义。

独立服务器通过 `--mode=server` 启动，不占玩家席位。`battle/battle_simulation.gd` 是服务器、单机、工作台共用的固定阶段编排；`battle/match_session.gd` 管理两席玩家身份与连接映射。客户端只驱动输入和表现；精确协议见[联网契约](../docs/reference/NETWORK_PROTOCOL.md)。


联机时间与操作：`battle/network_clock.gd`校准服务器时钟，`battle/network_command_state.gd`保存出牌/技能的公开准备与完成身份，`battle/network_playback.gd`按同一Tick时间轴应用快照/表现事件。只有CommandSchedule/BattleSimulation执行真实命令，客户端时间轴不能驱动战斗规则。
