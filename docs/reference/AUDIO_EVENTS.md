# 音频事件与生命周期参考

接入顺序见 [音频流程](../AUDIO_INTEGRATION.md)。能力由 PresentationEvents、实际派发方、GameAudioManager 和 validator 共同约束；字段可用不代表每个对象已经配置声音。

## 声音池与来源

声音池必须非空、资源可加载为 AudioStream。攻击分段按实际攻击序号映射，不按文件名排序；随机池避免连续重复。默认事件总线 Combat，可选 Voice，事件默认额外增益 0 dB；普攻专用默认值以读取方为准。

`team_overrides` 提供蓝红平级覆盖，禁止递归；形态和阵营选择统一经 PresentationConfig。出手时保存单位、卡牌、形态、阵营、序号、首击/强化状态，后续命中不重新查当前来源形态。

## 事件范围

| 配置 / 事件 | 触发或限制 |
| --- | --- |
| `attack_swing / attack_hit` | 普攻出手 / 真实伤害成功；空挥与免疫不伪造命中 |
| `attack_hit_by_segment / attack_launch_by_segment` | 与普攻段对齐；分段发射替代普通发射池 |
| `attack_hit_once_by_segment` | 单文件已含多刀时按出手去重，只影响声音 |
| `attack_swing_lead_time` | 在 first_hit 减提前量处播放；控制取消旧攻击时停声、后续不补播 |
| `attack_launch / attack_missile_cast / empowered_launch` | 实际弹体创建；强化发射替代普通池，不叠加 |
| `first_strike:*` | 首击的出手、弹体起手/发射、真实命中；需对应机制 |
| `empowered_ready / empowered_swing / empowered_buff:*` | 强化待击就绪、出手与状态起止 |
| `active:cast` | 单位主动技能成功开始施放时派发一次；支持没有 visual_action 的瞬时技能；不等于效果命中 |
| `active_buff:* / resource_full / passive_heal` | 实际增益、进入满资源、实际回血 |
| `action:start/sustain/end/voice` | 已携带动作的窗口与语音，按序号去重 |
| `action:release` | 实际发射；直接范围技能按其真实入口处理 |
| `action:hit / hit_center` | 真实命中；nova、dual_form 等已有入口，中央可附加音层 |
| `action:hit_first/middle/last` | 多剪真实命中阶段；每剪多目标一次，缺省回退 hit |
| `action:hit_*_center` | 多剪中央替代对应普通池；同剪中心与边缘不重复叠放 |
| `action:impact / wave_hit` | 前方区域落地 / 冲击波成功命中新目标 |
| `action:zone_sustain/zone_end` | 已生成的固定区域，独立于施法者 |
| `continuous_attack:start/release/sustain/end` | 持续攻击状态，独立层 |
| `pre_deploy:start / deploy:start / spawn:start` | 预部署 / 有部署窗口的生成 / 零部署出生 |
| `deploy:hit / deploy:voice / death / death:voice` | 部署真实命中、部署语音、死亡音效与独立死亡语音各一次 |
| `replacement:start / revival:sustain/end` | 死亡替身、孵化过程、真实成功复生 |
| `idle:sustain / shroud:*` | 既有待机或缠流状态；机制支持不表示当前卡已启用 |
| `spell:cast / shield:cast/applied` | 成功施法 / 范围护盾施放及目标实际获盾 |

穿透弹体按成功命中的目标去重；非穿透扇形箭的声音按施法首次成功命中去重。伤害去重与音频去重分别维护，不能由播音次数反推伤害。

## 谁持有持续声音

| 持有者 | 停止与恢复 |
| --- | --- |
| 单位动作、增益、吐息、缠流、待机 | 分层管理；普攻受控取消，普通技能眩晕继续、冰冻取消，增益/待机不因普通控制暂停；死亡/销毁/换场清理。待机离开状态即停 |
| 固定技能区域 | 按区域自身时长；自然结束可播消散声，清场不补结束声 |
| 普通弹体尾音 | 开启 attack_launch_until_impact 时，每枚弹体独占；命中、失效、清场或播完释放 |
| 定时孵化 | 独占非循环过程，控制不暂停；死亡停止，成功可延续同一尾音 |
| 系统建筑 | 出生与待机独立持有；水晶交叉淡化 1.5 秒，死亡和换场清理两路 |

动作/增益长片段不等于无缝循环；吐息、待机等可续播，也不保证 Wwise 样本级无缝。常规短音、持续层、区域和弹体池各有并发限制，不能无限创建播放器。

## 联网与出生细节

普通高频命中沿用不可靠事件；重要卡牌/区域/弹体启停用可靠 ID 去重，持续状态可由快照纠正。客户端只消费，不重复伤害来推断声音。来源死亡不取消仍有效的在途弹体，也不给死者发放回血等收益。

有部署窗口的首次附着仅在刚开始的 0.1 秒内播放 deploy:start，晚到不补；零部署的 spawn:start 在首次附着可播放，重绑不重播。系统塔破损按生命阶段单调推进，跨阶段只播目标阶段，初次附着不补历史破损。

全局播报配置在 match_audio，系统建筑在 world_audio，当前缺项见 [覆盖表](../AUDIO_CARD_MAP.md)。

`form:refresh`在存活单位的限时形态因击杀实际刷新时派发，可复用开启声音；它不重播变形动画、不重新增加最大生命。

## 动作进度音频节点

`audio.events.<action>:start/voice/release.action_time`可声明主动动作内的非负秒数，必须小于该技能cast_duration。仅用于声音起点，不能绑定hit/sustain/end，更不能驱动伤害。GameAudioManager读取权威/快照动作进度派发，忽略同名普通事件/RPC通知以免重播；同序号回退不重放，取消/死亡不留下定时任务，普通技能眩晕时继续，冰冻取消剩余节点。未配置action_time的声音行为不变。字段同时有形状、语义校验与生命周期回归。

独立结果创建声使用 `audio.events.<action>:start.owner: "result"`。仅支持已经声明 `independent_on_creation` 的普通/满层技能，不允许再绑定 `action_time`。权威创建事件同时提交结果和声音，单位动作观察不重复启动；冻结或来源销毁不切断已创建结果声。施法本体的 sustain 仍归动作。
