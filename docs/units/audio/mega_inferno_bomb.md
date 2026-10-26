# 终极爆弹音频

[返回终极爆弹](../mega_inferno_bomb.md) · [总索引](../README.md) · [素材结构](../effects/mega_inferno_bomb.md)

| 项目时机 | 原版事件 | 依据与处理 |
| --- | --- | --- |
| 水晶发射 | `Play_sfx_Ziggs_ZiggsR_OnMissileLaunch` | 基础皮肤事件表及Wwise事件，3个随机变体，原始事件增益-14dB |
| 在途持续 | `Play_sfx_Ziggs_ZiggsR_missilelaunch` | Bomb粒子的SoundPersistent直接引用；媒体445153616，原始-14dB，循环并随弹体移动；抵达/清场停止 |
| 权威抵达爆炸 | `Play_sfx_Ziggs_ZiggsR_hit` | R_explosion的SoundOnCreate直接引用；3个变体，媒体843236481/246534154/232586953，原始-8dB |

事件名大小写及`OnMissileLaunch`与`missilelaunch`是不同事件，不能合并。发射媒体199107897/396846892/161276618。Wwise随机容器决定变体，运行配置每事件最多3条。

另有OnCast（105228475/39798369/911287700，-14dB）及英雄语音：本卡从水晶发射、没有炸弹人Spell4施法动作，因此有意不接。`ZiggsRImpactSound_OnBuffActivate`（231097042/748487412/187193572，-14dB）与停止事件独立注册，但未恢复其Buff调用时序；它不是爆炸粒子直接绑定的hit事件，已撤下上一版误用的音轨。重伤与破盾不另配无关声音。

wwiser显式`-gv=0dB`，导入重新解码，保留事件原始增益；项目补偿0dB，经Combat总线，无归一化。来源与哈希见`assets/audio/original_gain_manifest.json`和本卡event_manifest；源BNK/WPK、TXTP与预览在开发素材库`03-制作中/终极爆弹/audio-source/ziggs/`。声音跟随可靠表现事件，客户端不重新结算。暂停恢复、终局、重开、清场沿统一音频生命周期。实际运行与录音结果见[改动记录](../../deliveries/2026-10-27_终极爆弹新卡.md)，未把触发日志当作主观听感验收。

最终源素材复核：7份TXTP全部重新解码，采样参数与PCM逐字节匹配正式WAV。持续声TXTP的#e及解码器元数据确认全长循环（44100Hz，0～136906样本），保留循环至抵达停止。声源位置与3D弹体共用抛物线高度函数，再按54度投影转换到2D音频坐标，避免旧正弦轨迹造成声画位置偏差。复核结果在素材库`03-制作中/终极爆弹/final-review-audio/results.json`。
