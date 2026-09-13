> 2026-09-14 整理前快照，可能含已纠正的说明。当前入口见 [文档首页](../../../README.md)。

# 维护结构与扩展入口

本文描述当前唯一流程。共同规则在 AGENTS，具体内容字段在 CARD_DESIGN，动画与音频细节分别在对应专项文档。

## 状态所有者与数据流

| 模块 | 拥有/负责 | 不负责 |
| --- | --- | --- |
| CardDB + cards/ + schema/validator | 每卡四域定义、一次构建的递归只读注册表、内容校验 | 单位运行状态 |
| Main | 场景生命周期、模块装配、玩家/AI/RPC 请求资格与费用、每 Tick 顺序 | 渲染时间决定胜负；模型/声音决定命中 |
| FixedStepClock | 20Hz 累加器和积压，按输入顺序执行全部 Tick | 静默跳 Tick |
| MatchRules | 正赛/加时时间与胜负结果 | UI 绘制、资源加载 |
| CommandSchedule | 卡牌、预部署、主动请求与 Cast/Impact 队列；暂停中的施法 | 卡牌资格与伤害效果 |
| MovementSystem + ArenaRules | 稳定排序候选、局部转向、接触贡献平均与限幅、空地分层推挤（见 [接触模型](../../../BATTLE_CONTACT_MODEL.md)） | 卡牌内容分支 |
| CombatResolver / ProjectileSystem | 真实命中、范围/附带效果、存活来源收益；在途来源值 | 动画或音频结束时结算 |
| Unit + ControlState + AttackTimeline | 通用单位行为与目标；控制聚合；当前攻击阶段状态 | 每英雄一个子类 |
| UnitPresentationState | 每单位复用的只读行为/动作/控制/速率/权限视图 | 新建平行的控制规则 |
| PresentationConfig / PresentationEvents | 统一形态选择；当前真实可派发 cue 的能力表 | 任意脚本语言/通用消息中间件 |
| UnitModel3D / BattleEffects2D / GameAudioManager | 独立消费只读状态和真实事件；动画/叠加/声音生命周期 | 主机权威数值 |
| CardDetails | 从定义生成卡牌属性、被动、主动说明；供 DeckBuilder 与内容回归共用 | 卡组选择、控件生命周期、权威结算 |
| MatchResources / CardArt | 本局依赖资源强引用、卡面发现缓存 | 消除模型实例化成本 |

数据流：输入 → Main 校验/扣费 → CommandSchedule → FixedStepClock 驱动 Unit/技能/移动/弹体/结算 → MatchRules → Snapshot 与纯表现事件 → 本地/客户端独立模型、2D 效果、音频和 UI。

SpellSystem 拥有冰冻/减速/治疗的区域与表现集合，ActiveSkillEffectSystem 拥有技能区域。BattleEffects2D 读取它们；Main 不再维护这些数组的别名。BattleContext 仍只是轻量服务入口。

## 三种扩展

普通复用卡：在 `scripts/data/cards/<id>.gd` 配 gameplay / visual / card_art / audio，添加 CardDB.DEFINITIONS 注册项，准备现有约定的包装/动画映射、卡面和经过核验的音频。通用内容测试自动遍历；只有独特规则或时序再增加专项断言。系统会递归准备双方卡组、兵线、召唤、变形与复生依赖，无须改 Main、Unit、动画控制器或音频管理器的卡名分支。

新状态表现：已有冰冻/眩晕/减速只补 visual_animations 映射或包装挂点。确实新增权威控制规则时扩展 ControlState/Unit 通用入口、只读视图及必要 Snapshot；纯表现覆盖放 UnitModel3D，并同步 schema/validator、网络/组合回归。不能借此改变控制暂停施法的规则。

新音频事件：先在真实机制中派发表现事件，再更新 PresentationEvents 能力表、GameAudioManager 消费、必要 RPC/去重和测试；最后才配置逐卡 audio 与已核验素材。普通攻击用出手来源 unit_id/card_id/form/serial/first_strike/empowered；高频命中保持不可靠，重要法术事件用可靠 ID，持续状态用快照纠正。没有派发入口的 cue 必须被 validator 拒绝。

## 保留的边界与限制

- 控制仍按现有“最长持续时间 + 最强倍率”聚合，同源和异源不乘算、不独立到期；主动 Buff 最长窗口/最高倍率/免疫 OR 也保留。需要按来源独立撤销时应作为新机制单独设计。
- Main 仍保留部署几何/卡槽资格与兵线编排，ActiveSkillEffectSystem/NetworkSnapshotSystem 仍与 Main 的比赛对象有一定耦合；没有为降行数把它们搬进另一个万能 controller。
- 攻击开始和控制恢复时对齐表现进度；快照间不逐帧硬 seek，尚未进行广域网高延迟/丢包长测。
- 单位持续声音区分 action/buff/attack/shroud/revival/idle；固定区域、弹体发射尾音、系统建筑出生/待机分别持有独立播放器。治疗已配置 spell:cast，冰冻和通用眩晕未配声音。来源与缺项见音频表；片段续播不等于 Wwise 样本级无缝循环。
- 头顶可配置稳定锚点；无锚点使用模型接入时的投影回退，不能动态追随每帧武器/披风最高点。实例化、网格和动画资源仍有内存/CPU 成本。
- 实际渲染四组画面已检查；不能把截图当作完整动作连续性或音频听感验收。手机、实际试听与广域网条件尚未验证。

验证命令见 [测试手册](../../../../tests/README.md)；结构收敛的历史问题、基线和性能采样见 [阶段验收归档](../../2026-09-11/maintenance_validation.md)。

## 维护与退役

`tests/mechanics_check.gd` 直接编排领域套件；工作台交互契约在 `workbench_suite.gd`，在主动技能测试的原有位置调用以保持场景时序。`tools/maintenance/audit_project.py` 只读检查本地文档链接、字面资源路径、卡牌注册/文档和孤立 UID；动态加载与运行行为仍由 Godot 回归负责。

离线音频工具在 `tools/audio/`，模型加工在 `tools/assets/`，候选地图构建在 `tools/arena/`。已退役素材进 `assets/archive/`（Godot 忽略），结束的研究与逐卡迭代进 `docs/archive/`。不以文件内容相同为由合并不同音频事件，也不删掉 GLB 外部依赖。
