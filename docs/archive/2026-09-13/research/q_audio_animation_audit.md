# 卡牌 Q 发射音与格温 Q 动画核对（2026-09-13）

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

## 卡牌大师

原始 TwistedFate.wad.client → data/characters/twistedfate/twistedfate.bin，转换后的 SpellObject `Characters/TwistedFate/Spells/SealFateMissile` 同时声明 `mMissileEffectKey = TwistedFate_Q_Mis`、`mHitEffectKey = TwistedFate_Q_Tar` 和声音事件 `Play_sfx_TwistedFate_SealFateMissile_OnMissileLaunch`。因此它是 Q 的弹体事件，不能只凭 SealFate 名字当作其他技能。

已新增 4 个原始随机变体（约 1.98–2.32 秒），保留事件 -21 dB 增益与原始尾音。`wild_cards:release` 复用现有 apply_frontal 派发，在 0.25 秒释放；与当前视觉牌飞出时间相同，每次施法播放一次，不按三张视觉牌重复叠加。原 WildCards_OnCast 出手层继续使用。本次不改权威伤害和飞行时间，不增加循环声。原数据也声明 OnHit（event_id=546443887），已按用户补充要求接入 `wild_cards:hit`。该事件是两层随机音色叠加，保留 TXTP 默认选中的一组双层组合与各层 -16/-22 dB 增益，导出约 1.15 秒。成功伤害时每次施法只播一次；空放不播。

后续按用户要求改为权威穿透弹体：0.25 秒出手生成三张牌，飞行时长/射程仍为 0.7177415 秒/190，碰撞前不扣血。每张牌扫掠沿途碰撞，命中继续飞行；同次施法三张牌共享目标去重，每目标只受 100 伤害一次。每个成功命中的目标在碰撞位置派发 hit 声音，空放不播。出手后的弹体独立于施法者存活，到射程末端清理。寒冰保持首次碰撞阻挡模式。视觉牌由权威弹体/客户端快照绘制，旧纯视觉三牌已关闭，避免双重显示。


## 格温

来源 Gwen.wad.client → data/characters/gwen/animations/skin0.bin（本机对应 `/Users/czh/Tools/lol-asset-tools/card_audio_batch/gwen/animations.ritobin`），以及角色 gwen.bin 的 GwenQ SpellObject。

原图节点：`Spell1` 是方向参数图，正前方分支 `Spell1_0`；中间 `Spell1_B`；最后 `Spell1_C` 也是方向参数图，正前方对应本项目 `Spell1_C_anm`。最后一剪后另有 ToIdle / ToRun 收势片段，本项目已配置这些出口。

原 mBlendDataTable 四条相关边均为 TimeBlendData.mTime=0：

| 边 | u64 键 |
| --- | --- |
| Spell1_0 → Spell1_B | 7509011031754399445 |
| Spell1_B → Spell1_B | 13417875674353753813 |
| Spell1_B → Spell1_C | 13417875674336976194 |
| Spell1_0 → Spell1_C | 7509011031737621826 |

这些数据支持“起手→按需重复中间剪→最后一剪”，含零层直接进入最后一剪。但混合表不是完整技能执行脚本，不给出层数循环次数、切换触发时刻或完整播放速度曲线。GwenQ 的脚本仅有名字，不能从它的单个 castTime 值推算出整套多段动作。当前资源无法据此恢复原版完整调度。

现有结构与原图一致，本次不另造替代拼接、不改变已有命中点或合成音轨。保留项目 0–3 层对应 2–5 剪的规则，所有档位固定 1.5 秒：

| 层数 | 起手时长 | 中间剪 | 最后一剪时长 | 合计 |
| --- | --- | --- | --- | --- |
| 0 | 0.9493669 | 无 | 0.5506331 | 1.5 |
| 1 | 0.7827002 | 0.1666667 × 1 | 0.5506331 | 1.5 |
| 2 | 0.6160335 | 0.1666667 × 2 | 0.5506331 | 1.5 |
| 3 | 0.4493668 | 0.1666667 × 3 | 0.5506331 | 1.5 |

起手裁剪与以上时间分配是项目适配，不是原表提供的时间表。代码注释已明确这一边界。单位已经对齐攻击方向，所以继续采用正前方分支，未引入原播放器连续方向混合。

## 验证

完整 mechanics 546 项通过，含格温四档 1.5 秒/中间剪原速及命中时间线检查。格温双方动画实际渲染完成（各 27 张/记录，工具失败数 0），检查了满层中间剪画面；四档实战分别触发 active_0–3 音轨并生成非静音录音。卡牌 Q 实战日志确认 sustain→release→hit 派发并录音；素材哈希与原始事件可追溯。git diff --check 通过。主观试听尚未完成，不将派发日志当作听感验收。

## 后续：穿透弹体与格温命中音

`projectile_piercing` 是可选 frontal/fan 技能字段，与 `projectile_stop_on_hit` 互斥，共用 ProjectileSystem 路径碰撞。无角色名称分支，不让表现决定伤害。沿途碰撞按距离/实例 ID 排序，大步长也不会跳过前后排；同次施法目标去重不受弹体重叠或后续 Tick 影响。卡牌形状与高度通过原有快照字段传递，命中声音沿用可靠 card_event RPC 与事件 ID 去重。

格温原始 TXTP 确有 `GwenQFirst_hit` / `GwenQMiddle_hit` / `GwenQLast_hit`，现各接 3 个随机变体。多段权威命中排程携带 first/middle/last，成功命中时播放 `active_N:hit_first/hit_middle/hit_last`，每剪多目标只播一次，空剪不播。零层为 first→last，满层为 first→middle×3→last，持续出手音轨与 1.5 秒总时长不变。普通 hit 作为未配置分段池时的兼容回退。

原库还有 center、minion 等条件变体；本次选基本命中池，未模拟这些额外音色条件，不能称为完整原游戏目标材质/中心命中音频规则。完整媒体编号、原始事件 ID、源 TXTP、时长与哈希记录在 Gwen event_manifest.json。

本次最终验证：553 项 mechanics 全部通过；新增穿透多目标/重叠去重/路径空隙/友军/射程清理/死后在途/互斥 schema 及格温首中末命中与空剪回归。实际工作台录制卡牌、格温非静音音轨，目视确认真实三牌飞行截图 `/tmp/pierce-flight.png`。第二次本机 host/join fixture 双端确认卡牌穿透前后排两次 hit，以及格温 active_3 首/中×3/末命中事件；无脚本错误。首次 fixture 退出出现资源清理警告，补足退出等待后第二次未复现。主观听感尚待人工试听。
