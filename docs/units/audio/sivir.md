# 战争女神声音

[返回战争女神](../sivir.md) · [返回单位索引](../README.md)

| 时机 | 来源 |
| --- | --- |
| 部署语音 | 中文客户端希维尔禁用语音“公事公办而已。” |
| 投掷起手 | 原版Q OnCast，最多3变体 |
| 发射 | 原版QMissile OnMissileLaunch，最多3变体 |
| 实际命中 | 原版Q_hit，最多3变体；空放不播放 |
| E开盾 | 原版E OnBuffActivate，最多3变体 |
| E抵挡或到期 | 同一原版E OnBuffDeactivate |
| 死亡音效 | Death3D_cast，不超过1.5秒；不使用 death:voice |

事件由权威出手、实际碰撞和护盾消费派发，沿现有表现事件同步。原版事件增益保留，wwiser显式0dB，无逐文件归一化。折返时按原版QMissileReturn事件播放回程声，保持弹体出手时的归属，即使来源死亡仍可播放。接住时没有独立原版声音，保持静音。无走路声音。

原事件、变体与加工见[资源清单](../../../assets/audio/units/sivir/event_manifest.json)。素材与实战试听状态见本次交付记录。
