# 中型雷电法术音频

[返回卡牌](../medium_lightning.md) · [返回总索引](../README.md)

| 实际事件 | 原版基础皮肤声音 | 接入 |
| --- | --- | --- |
| E开始（施法方） | VolibearE_OnCast + VolibearE_buffactivate | 保留原事件内0.1秒、1秒分层延迟和自然尾音 |
| E敌方预警 | VolibearE_enemy_buffactivate | 施法后1秒，仅敌方播放 |
| E落雷（含空放） | VolibearE_explo | 施法后2秒 |
| E真实命中敌方 | VolibearE_hit | 命中结算成功后，每目标一次 |
| 存活防御塔受失效 | VolibearRTowerDisable_hit | 每座塔一次，保留完整2.37秒尾音 |
| 防御塔失效持续 | VolibearRTowerDisable_buffactive | 从失效开始播放，2秒到期发送Stop；原版1秒Exp1淡出；死亡同样收尾，同塔刷新和清场立即清理 |

全部由原银行以wwiser显式`-gv=0dB`生成事件、vgmstream重新解码，无归一化或文件后期增益。按用户要求，R塔失效命中声与持续声统一使用-12dB运行播放衰减；E各阶段仍为0dB。预警使用原事件随机池的一个原生分支；不把随机分支混成多层。停止事件ID2377787124指向Action705798628，原银行TransitionTime=1000ms、eFadeCurve=6（Exp1）；运行时采用wwiser对应插值`1-(t+1)*t/2`，淡出不延长塔失效。

声音经可靠表现事件派发和去重，客户端不猜命中。塔失效持续声由目标塔持有，遵守公共暂停与清场生命周期；不跟随施法方水晶死亡而终止。

用户反馈塔失效声偏大后，已重新解码并比对PCM：原有E落雷与R塔失效命中两条音轨逐样本一致，无额外放大。R命中原事件包含-8/-10dB两层，输出峰值-3.32dBFS、RMS -21.95dBFS；E落雷峰值-12.05dBFS、RMS -27.29dBFS，因此原事件输出的RMS相差约5.3dB。`0dB`补偿不代表同响度，也不能据此声称与LoL客户端最终混音一致；空间衰减和总线处理由本项目统一管理。

法术没有英雄部署、死亡或角色语音；强化护盾仍沿用本项目通用反馈，未将狗熊专属自护盾循环套给所有友军。来源见[事件清单](../../../assets/audio/spells/medium_lightning/event_manifest.json)和[原增益清单](../../../assets/audio/original_gain_manifest.json)。已在工作台实际播放并录音；主观听感仍待用户试听。
