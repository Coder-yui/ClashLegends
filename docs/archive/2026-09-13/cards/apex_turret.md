> 整理前快照，归档于 2026-09-13；含已被后续段落替代的数值与判断。当前入口见 [卡牌手册](../../../units/apex_turret.md)。

# H-28Q尖端炮台（`apex_turret`）

当前定义：[`scripts/data/cards/apex_turret.gd`](../../../../scripts/data/cards/apex_turret.gd)，使用 gameplay / visual / card_art / audio 四域；通用接入与验收见 [卡牌设计](../../../CARD_DESIGN.md)。

## 1. 属性数据

| 属性 | 数值 |
| --- | --- |
| 类型 / 费用 / 可选 | 建筑 / 5 / 是 |
| 定位 | 强力远程防守建筑；普攻炮弹造成小范围对地伤害 |
| 生命值 / 普攻伤害 / 攻击距离 | 1450 / 130 / 220 |
| 攻击间隔 / 首次出手 | 1.50 s / 0.55 s |
| 弹体速度 / 溅射半径 | 420 px/s / 32 px |
| 权威半径 / 表现半径 | 40 / 55 |
| 占地 | `3 × 3` 格（`Vector2i(3, 3)`） |
| 空中单位 / 仅攻击建筑 / 可攻击空中 | 否 / 否 / 否 |
| 建筑寿命 | 45.0 s；无外部伤害时生命匀速衰减为 0 |
| 队伍圈 | 不显示 |

费用之外未由需求指定的战斗数值均为本次接入采用的初始平衡值，后续只需修改 `scripts/data/card_db.gd`。

## 2. 普通攻击

- 只选择地面敌人，使用 `Attack1`。
- 在权威出手时生成追踪炮弹；炮弹抵达目标后，对目标周围半径 `32` 的敌人造成 `130` 点伤害。
- 普攻将 `ground_only` 作为通用攻击效果随弹体携带，因此溅射范围中的空中单位也不会受伤。
- 炮弹使用 `2.25×` 的橙红色能量弹表现，命中时绘制扩张至 `32 px` 的爆炸波和范围环；视觉尺寸不改变弹体到达判定。

## 3. 主动技能：海克斯穿透激光

- `kind = frontal`、`shape = trapezoid`，近端宽与远端宽由 `24` 增加 20% 至 `28.8`，形成长度 `270` 的等宽穿透路径。
- 一次 Gameplay Impact 会命中路径内所有敌方地面战斗对象，各造成 `240` 点伤害；空中与路径外目标不受影响。
- 消耗 `1` 金币；每个炮台最多使用 `2` 次；每次使用后冷却 `2.0 s`。
- 使用 `Attack_Beam` 动画，总施法时间 `1.6666664 s`；`0.45 s` 发射宽 `28.8 px` 的电磁波光弹，飞行 `0.30 s`，`0.75 s` 由固定 20Hz 权威模拟结算伤害。
- 施法锁定移动、普通攻击与朝向。动画和激光绘制都不驱动伤害。

## 4. 美术素材

- 正式包装场景：`res://assets/units/apex_turret/apex_turret_view.tscn`。
- 包装场景整体放大为原来的 `1.375×`，表现半径为 `55`；权威碰撞半径仍为 `40`。
- 源模型来自 `待开发卡牌美术素材/大发明家 (2).glb`，已移动到 `assets/units/apex_turret/source/apex_turret.glb`，因此待开发队列少一个素材包。
- 真实动画映射：部署 `Spawn`、待机 `Idle1`、普攻 `Attack1`、主动 `Attack_Beam`、死亡 `Death`。
- 普通炮弹和主动电磁波光弹均从放大后炮口对应的高度/前向偏移 `46.75 px` 出现；偏移只修正表现，弹体飞行和技能命中仍使用权威坐标。
- 卡面：`res://assets/cards/apex_turret_loading.png`，由 `tools/capture/capture_apex_turret_card_art.gd` 使用正式 3D 模型与主动姿势拍摄。

## 音频接入（2026-09-11）

已接入的动作、原始事件与文件见 [音频映射](../../../../assets/audio/units/apex_turret/README.md)。完整动作对照、来源、自动验证及待人工试听项见 [全卡音频对照](../../../AUDIO_CARD_MAP.md)。本轮不改变既有 2D / 3D / 卡面状态；音频来自外部 LoL 原始库只读提取，未移动待开发队列素材。

## 2026-09-12 原始动画表复核

核对HeimerTBlue/HeimerTYellow图，仅采用两图共同明确的3条当前片段混合；激光与部署、0.8秒死亡窗口均保持。

来源、行号与保留理由见 [兵线与建筑对照](../research/animation_group_buildings_minions.md)。

2026-09-13 全面音频复核：[逐项结果与验证](../research/hero_audio_completeness_audit.md)。当前可明确对应的普攻/被动/已接技能缺项已补入；不引入原版未实现技能或未经确认的条件音。

### 连续音轨与事件去重修订（2026-09-13）

按用户指定，将 Play_sfx_HeimerTBlue_HeimerdingerRQEngineAudio_OnBuffActivate 接入 deploy:start，保留原始 -26 dB 事件增益。原事件解码约 12 秒，部署时一次性启动，不循环，不作为普攻触发。

## 2026-09-13 音频阶段复核

部署只播放中文 HeimerdingerQUlt_cast3D（强化 Q）四选一；RQEngineAudio 改为 idle:sustain 待机引擎，部署/攻击/技能时不播放，死亡销毁清理。普攻 OnCast / OnMissileLaunch / OnHit 三个事件分别映射出手 / 0.55 秒生成弹体 / 真实命中。激光 OnCast 蓄能、OnMissileLaunch 出膛、OnHit 命中完整；修正发射音原先到 0.75 秒命中才播放的问题，现在在 0.45 秒权威排程节点发声，0.75 秒仍按原逻辑统一结算伤害。声音与战斗数值互不驱动。

完整 mechanics、实际运行录音与 host/join 事件复核通过；来源和逐项映射见 assets/audio/units/apex_turret/README.md。待机语义以本节为准，取代之前部署引擎说明。

## 2026-09-13 最终部署／死亡与真实激光弹体

当前音频映射取代上节：不使用英雄 QUlt_cast3D。部署使用 Q 炮台 QSpawnDestroyAudio_OnBuffActivate 三选一，死亡使用 OnBuffDeactivate 三选一；RQEngineAudio 仅待机。对应资源和导入脚本见音频目录 README。

激光 0.45 秒出膛，创建真实 ProjectileSystem 穿透弹体；宽 28.8px（权威半径 14.4），沿 270px 路径飞行 0.30 秒。取消原先到 0.75 秒统一结算：现在按移动目标的当前位置做每 Tick 扫掠碰撞，依次穿透沿途地面目标，每目标只伤害一次并播放一次命中声。已出膛弹体在炮台死亡后继续飞行；未出膛则随炮台死亡取消。炮口高度/前移只影响绘制。

mechanics 覆盖近远依次命中、路径外/空中排除、移动躲避、炮台死亡后在途命中、每目标去重与射程结束清理。双阵营实战图及 host/join 弹体/音频复核由 apex_audio_review.gd 提供。

## 2026-09-13 数值体系统一

当前施法窗口1.67秒；生命衰减继续按余量累计扣整数。 当前规则以 [数值体系](../../../NUMERIC_SYSTEM.md) 及逐卡定义为准，前述日期记录保留历史值。
