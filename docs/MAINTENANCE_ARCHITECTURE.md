# 项目结构与维护边界

本页说明状态由谁持有、改动应落在哪里。共同规则见 [AGENTS](../AGENTS.md)，测试命令见 [测试手册](../tests/README.md)。

## 模块职责

| 模块 | 负责内容 |
| --- | --- |
| CardDB、逐卡定义、schema/validator | 只读内容与字段校验 |
| Main | 比赛生命周期、模块装配、请求资格、费用与每步编排 |
| FixedStepClock | 固定 20Hz 时钟与积压，执行全部 Tick，不静默丢步 |
| MatchRules / CommandSchedule | 比赛规则；卡牌与技能排程 |
| Unit、ControlState、AttackTimeline | 通用单位、控制聚合和普攻状态 |
| MovementSystem、ArenaRules、路径搜索 | 移动、部署几何、局部避让、碰撞与寻路 |
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
- **工作台：**UI 在 `scripts/ui/development_workbench.gd`，模型预览和场景配方在 `scripts/ui/workbench/`；仍复用正式出牌/技能接口。

## 需要保留的语义

控制采用最长时间、最强倍率聚合，不按来源相乘；主动增益保留最长窗口、最高倍率和免疫合并。按来源独立撤销属于新机制。

在途弹体保存出手时来源与形态，来源死亡后仍可命中，但不给死者回血或技能资源。音频与模型不驱动伤害、移动或联网状态。

快照版本与固定载荷必须同时维护读写端；当前版本 13，单位载荷 38 项，修改协议需提升版本。晚到表现按进度对齐，重复序号不重播。

## 维护与已知限制

核心测试由 `tests/mechanics_check.gd` 统一编排，工作台套件在主动技能套件后独立运行。维护审计检查资源、链接、注册和孤立 UID，不能替代运行回归。

离线加工放 `tools/`，已退役素材放受 Godot 忽略的 `assets/archive/`，已结束研究放 `docs/archive/`。不因内容相同就合并不同音频事件，不能删除模型外部纹理或可编辑源件。

目前仍有 Main 与领域系统的耦合；资源预留也不消除实例化成本。性能和设备验证的缺口见 [开发状态](DEV_PLAN.md)，历史测量见 [结构验收](archive/2026-09-11/maintenance_validation.md)。
