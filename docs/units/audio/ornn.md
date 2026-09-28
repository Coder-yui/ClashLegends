# 奥恩 · 音频接入

[← 返回奥恩总览](../ornn.md) · [总索引](../README.md)

## 声音与触发时机

基础皮肤普攻三段分别使用对应的出手与命中事件；部署从“奥恩出品，必属精品。”、“好吧，我们走。”、“回炉去了。”三句中随机选择，来源为中文客户端选人、禁用及英雄语音资源。被动使用原生 OrnnP_forging，发锤前3.6秒开始；成功抵达播放通用购买装备成功声。冲锋接入E起手、冲刺脚步、路径命中、撞停爆发及范围受击声音，范围受击借用原生击飞声，玩法仍为眩晕。

| 发生时机 | 接入变体 | 代表试听 |
| --- | ---: | --- |
| 部署语音 | 三句随机 | [奥恩出品](../../../assets/audio/units/ornn/deploy_quality_zh_cn.wav) · [好吧，我们走](../../../assets/audio/units/ornn/deploy_choose_zh_cn.wav) · [回炉去了](../../../assets/audio/units/ornn/deploy_ban_zh_cn.wav) |
| 普攻出手 | 每段3个 | [Attack1](../../../assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack_oncast_r1_d.wav) · [Attack2](../../../assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack2_oncast_r1.wav) · [Attack3](../../../assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack3_oncast_r1_d.wav) |
| 普攻命中 | 每段3个 | [Attack1](../../../assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack_onhit_1559186049_1153642577_r1_d.wav) · [Attack2](../../../assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack2_onhit_1559186049_1153642577_r1.wav) · [Attack3](../../../assets/audio/units/ornn/play_sfx_ornn_ornnbasicattack3_onhit_1559186049_1153642577_r1_d.wav) |
| 发锤前3.6秒 | 原生锻造音效 | [锻造](../../../assets/audio/units/ornn/forge_equipment.wav) |
| 冲锋起手 | 1个事件 | [起手](../../../assets/audio/units/ornn/play_sfx_ornn_ornne_oncast.wav) |
| 撞停爆发 | 1个事件 | [撞停](../../../assets/audio/units/ornn/play_sfx_ornn_ornne_buffonmoveend_explosion_r.wav) |
| 冲刺脚步 | 原生E_fs变体，冲刺三个步点 | [试听](../../../assets/audio/units/ornn/charge_step_1.wav) |
| 路径命中 | EKnockAway变体，每目标一次 | [试听](../../../assets/audio/units/ornn/charge_trail_hit_1.wav) |
| 爆发受击 | EKnockUp，每个受伤目标处 | [试听](../../../assets/audio/units/ornn/charge_knockup_1.wav) |
| 增幅成功抵达 | Play_sfx_hud_store_buy | [试听](../../../assets/audio/units/ornn/forge_arrive_1.wav) |
| 死亡 | 3个语音变体 | [试听](../../../assets/audio/units/ornn/play_vo_ornn_death3d_r1_zh_cn.wav) |


## 锻造与声音生命周期

锻造声音保留完整5.398秒；权威锻造计时在开始3.6秒后发锤，声音播放进度不驱动发射。眩晕、冰冻、凝滞截断锻造声音；发锤前打断则解除后从头播放并重锻3.6秒，发锤后只切声音尾段，已发出的锤子继续飞行。

锻造声绑定来源单位，可停止且跟随其位置；购买成功声在锤子抵达且增幅成功时播放，绑定独立结果，来源死亡也可播放。抵达判定失败不派发声音。完整目标准入和周期规则见[奥恩手册](../ornn.md)。冲刺脚步按原生E步点映射到0.5秒冲刺，不使用持续循环。

## 来源与加工

来源与精确文件哈希见[清单](../../../assets/audio/units/ornn/event_manifest.json)。部署台词元数据与本地MLX转写交叉核对；三个文件独立进入 `deploy:voice` 随机池。其中“回炉去了。”来自中文客户端禁用语音 `champion-ban-vo/516.ogg`；“奥恩出品，必属精品。”来自 `Play_vo_Ornn_OrnnP_allypurchasesitem` 的 r7。

锻造音效来自 event 3114075896 → media 515457883。购买成功音来自 Common.wad.client 的 hud_global_audio 银行，事件 `Play_sfx_hud_store_buy`（1989001022），媒体41429280。

2026-09-28峰值复核：原事件浮点峰值最高+1.943dB，前次直接PCM16造成截断。全部21个SFX重新按原始TXTP解码为浮点，统一降低3dB再转PCM16，保持事件之间相对层次；语音保持原处理。

已在实际运行触发部署与锻造音轨，机器检查不代替主观听感确认。

[← 返回奥恩总览](../ornn.md)
