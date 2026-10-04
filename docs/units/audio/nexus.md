# 水晶 · 音频接入

> 当前增益基准（2026-10-04）：声音已从原版源事件重新导出，关闭工具 auto；文件制作增益和播放补偿均为 0 dB。裁剪、变速、包络及事件时机保留。本页旧调校段落中的额外 dB、统一制作余量属于重导前记录，已由此基准替代；原事件内部各层增益仍保留。详见[重导交付](../../deliveries/2026-10-04_原版增益音频重导.md)。


[← 返回水晶总览](../nexus.md) · [总索引](../README.md)

## 目前能听到什么

出生阶段按原生动画节点同时触发出生声和持续运转声：出生声自然收尾，运转 WAV 在音频层循环。水晶被摧毁时停止这两层并播放对应红蓝方的爆炸声音。

红蓝方统一在爆炸播放到 5.0 秒时开始胜利或失败播报，以实际音频播放位置计时。播报自然播放完毕后，在 1 秒内淡出本局所有剩余音频并结束终局声音序列。仅防御塔决定胜负时立即播报，并执行同样的 1 秒淡出。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 红方 · 死亡 | 1 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_global_eog_chaosnexus_death_cast_r1.wav) |
| 红方 · 持续待机声 | 1 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_sruap_chaos_nexus_alive_loop_r1.wav) |
| 红方 · 出生 | 1 | 0 dB | [试听 1](../../../assets/audio/world/chaos/play_sfx_env_sruap_chaos_nexus_spawn_r1.wav) |
| 蓝方 · 死亡 | 1 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_global_eog_ordernexus_death_oc_r1.wav) |
| 蓝方 · 持续待机声 | 1 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_sruap_order_nexus_alive_loop_r1.wav) |
| 蓝方 · 出生 | 1 | 0 dB | [试听 1](../../../assets/audio/world/order/play_sfx_env_sruap_order_nexus_spawn_r1.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 使用边界与待补项

当前出生、待机、死亡没有已确认缺项；水晶不攻击，也不需要攻击声音。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/event_expansion_manifest.json)

[← 返回单位总览](../nexus.md)
