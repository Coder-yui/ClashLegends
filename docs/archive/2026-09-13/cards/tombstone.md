> 整理前快照，归档于 2026-09-13；含已被后续段落替代的数值与判断。当前入口见 [卡牌手册](../../../units/tombstone.md)。

# 墓碑（`tombstone`）

当前定义：[`scripts/data/cards/tombstone.gd`](../../../../scripts/data/cards/tombstone.gd)，使用 gameplay / visual / card_art / audio 四域；通用接入与验收见 [卡牌设计](../../../CARD_DESIGN.md)。

## 1. 属性数据

| 属性 | 数值 |
| --- | --- |
| 类型 / 费用 / 可选 | 建筑 / 3 / 是 |
| 描述 | 持续召唤小鬼的建筑，适合建立防守屏障并拖延敌军。 |
| 生命值 | 400 |
| 攻击伤害 / 攻击距离 / 移速 | 0 / 0 / 0 |
| 攻击间隔 | 1.0 s（建筑不进行普通攻击） |
| 权威半径 / 表现半径 | 40 / 50 |
| 占地 | `3 × 3` 格（`Vector2i(3, 3)`） |
| 空中单位 / 仅攻击建筑 / 可攻击空中 | 否 / 否 / 否 |
| 建筑寿命 | 10.0 s |
| 队伍圈 | 不显示（`show_team_ring = false`） |
| 阵营颜色 | `Color(0.45, 0.40, 0.35)` |

## 2. 被动

### 周期召唤

- 部署完成后立即召唤 `2` 个 `imp`。
- 之后每 `5.0 s` 召唤 `2` 个 `imp`；`spawn_side = map_side`，召唤位置位于墓碑所在地图半区一侧。
- 建筑寿命结束或被摧毁时触发亡语，额外召唤 `2` 个 `imp`。
- 小鬼不是独立卡牌，具体属性见 [imp.md](../../../units/imp.md)。

## 3. 主动技能

**亡者集结**（`kind = summon`）

- 当前主动技能数值：消耗 `1` 金币；每个墓碑最多使用 `1` 次；每次使用后冷却 `10.0 s`。
- 以墓碑为中心环形生成 `4` 个 `imp`，生成间距会考虑墓碑与小鬼的权威半径。
- 直接生成，没有施法窗口、延迟或主动专属动画。

## 4. 使用的动画

- 场景：`res://assets/units/tombstone/tombstone_view.tscn`；`visual_forward_yaw = 0`。
- 包装场景整体放大为原来的 `1.25×`，表现半径为 `50`；权威碰撞与小鬼生成间距仍读取半径 `40`。
- 部署：`Spawn`。
- 待机：`Idle1`。
- 死亡：`Death`，表现时长 `0.8 s`。
- 周期召唤、亡语和“亡者集结”没有额外配置的 AnimationPlayer 动画，召唤由权威建筑生命周期逻辑执行。

## 音频接入（2026-09-11）

本轮保持静音，缺口与原因已记录。完整动作对照、来源、自动验证及待人工试听项见 [全卡音频对照](../../../AUDIO_CARD_MAP.md)。本轮不改变既有 2D / 3D / 卡面状态；音频来自外部 LoL 原始库只读提取，未移动待开发队列素材。

## 2026-09-12 原始动画表复核

按YorickWGhoul原表将Spawn→Idle1改为零混合，保留0.8秒Death，不猜QuickDeath序列选择条件。

来源、行号与保留理由见 [兵线与建筑对照](../research/animation_group_buildings_minions.md)。

## 2026-09-13 事件音频补充

部署使用 `Play_sfx_Yorick_YorickW_OnHitLocation`，死亡使用 `Play_sfx_Yorick_YorickW_death` 的 4 个变体。墙体持续生存循环已找到但未接入（需要独立生命周期，不能当作短音）。

音频映射与剩余项见 [事件接入记录](../research/event_audio_expansion.md)。资源导入及完整 mechanics 回归通过，实际运行已录音；最终响度与尾音听感待人工复听。

## 2026-09-13 太阳圆盘与墓碑正式接入

太阳圆盘已接入 AzirObeliskSound_OnBuffCast 生成、OnBuffDeactivate 消失、共享防御塔出手/发射/命中，原盾技能施放声保持，获盾声仍不使用。来源与处理见各音频目录 building_event_manifest.json；导入器 tools/audio/import_sun_disc_tombstone_audio.py。

- 当前保留 1 秒权威部署。Spawn 原片约 4.9667 秒适配这 1 秒；生成声音的前 4.9667 秒保音高压缩到 1 秒，其后的消散尾音保持原速，原声音内 3.5 秒的延迟层约在 0.705 秒进入。旧动画表的 Obelisk_buffcast/buffactivate 与当前声音银行 ObeliskSound 事件名称不同，采用语义/时序适配，不宣称恢复原客户端脚本。
- Death 恢复原片约 3.6667 秒；消失声完整播放，不套单位死亡 1.5 秒截断。权威死亡即时生效，动画和尾音不延迟伤害、碰撞或寿命结算。
- Attack1_BASE / Attack2_BASE 都启用，沿用项目确定交替选择；按原图 Disk 遮罩仅保留 Chest_Loc / Obelisk_Tip 骨骼轨道，不驱动基座。库在实例中复制，原 GLB 保持不变。
- Idle 参考原图 60/40 分支：三次简单 Base、两次 Base→Idle2→Base，展开成 9 段确定循环；没有新增原版随机选择器。相关片段间采用原表零混合。
- 普攻原始事件增益保留，项目三层分别额外 −6 dB，为双方同时攻击预留混音余量。出手读攻击序号，发射读真实弹体创建，命中读真实碰撞；音频不驱动弹道或伤害。
- 墓碑已接 YorickWWallLife_OnBuffActivate 持续层：部署结束进入待机开始，结束续播，冻结/眩晕暂停，死亡/销毁/清场停止。项目墓碑普通和瞬时召唤主动均可保持待机，不把生存循环当普攻。

验证：完整 mechanics 通过，新增墓碑持续声生命周期检查，更新太阳圆盘双攻击遮罩及待机循环回归。双阵营实际渲染、事件日志和混音录音来自 tools/demos/sun_disc_tombstone_review.gd，输出 /tmp/clash-sun-disc-tombstone。主观听感仍需用户复听。
