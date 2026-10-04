# 图奇 · 音频

> 当前增益基准（2026-10-04）：声音已从原版源事件重新导出，关闭工具 auto；文件制作增益和播放补偿均为 0 dB。裁剪、变速、包络及事件时机保留。本页旧调校段落中的额外 dB、统一制作余量属于重导前记录，已由此基准替代；原事件内部各层增益仍保留。详见[重导交付](../../deliveries/2026-10-04_原版增益音频重导.md)。


[返回图奇](../twitch.md) · [总索引](../README.md)

| 时机 | 已接入 |
| --- | --- |
| 普攻起手 | TwitchBasicAttack_OnCast，两段动作共用变体池，-3dB |
| 弩箭发射 | TwitchBasicAttack_OnMissileLaunch，0dB |
| 实际命中 | TwitchBasicAttack_OnHit，-5dB；普通攻击使用 |
| 火力全开开始 / 结束 | TwitchFullAutomatic_OnCast / OnBuffDeactivate，0dB |
| 死亡 | 中文Death3D，沿通用死亡包络加工 |
| 入隐 | 原版 Q HideInShadows_OnCast 第一变体，2.404秒，-3dB，用于脱战入隐切换 |
| 攻击破隐 | 原版 Q HideInShadows_OnBuffDeactivate，1.106秒，-3dB |
| 部署语音 | “嗨。”、“哦，你好。（图奇 大笑）”、“是我。（图奇 大笑）”随机一个，保留笑声尾段 |
| 行走 | 有意静音；初始隐身不补播切换音 |

大招期间发射使用TwitchSprayAndPrayAttack_OnMissileLaunch，真实命中使用OnHit，分别3个原版随机变体。出手时保存增益标志，来源死亡或技能结束不改变在途命中声音。OnCast在源事件中复用普通攻击相同WEM，因此保留共用起手音。没有持续音轨；实战事件已运行，主观混音、暂停恢复和并发听感仍待人工试听确认。

来源和处理见[音频清单](../../../assets/audio/units/twitch/event_manifest.json)。

[返回图奇](../twitch.md)

入隐与破隐声音只由权威状态边沿派发，开大招不触发破隐声；客户端沿通用单位表现事件接收。Q生效事件含9.3秒持续层，本次不接入，避免两秒脱战循环叠音。

部署三句来自本地Twitch.zh_CN.wad.client的Spell3DQEnd事件r4/r1/r3；公开台词目录与本地Whisper转写交叉定位，没有引入同事件的“我刚刚躲起来了”。完整长度不压进一秒部署动画，Voice自然播完。
