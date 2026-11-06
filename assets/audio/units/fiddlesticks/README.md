# 草间人和远古恐惧音频

| 项目事件 | 原版事件 | 处理 |
| --- | --- | --- |
| 建筑deploy:start | Respawn3D_buffactivate | 2.15倍保调变速以匹配两秒部署，约2.05秒含尾音 |
| active:cast | FiddlesticksScarecrowEffigy_OnHitLocation | 固定试听版本前3秒，2.5–3秒线性淡出 |
| continuous_attack:start | FiddlesticksW_OnCast | 3变体、源增益 |
| continuous_attack:sustain | FiddlesticksWdrain_OnBuffActivate | 2变体、源增益，按每轮生命周期停止 |
| death | Death3D_effigies | 2变体，建筑完整约2.15秒，移动形态1.5秒淡出 |

原英雄死亡语音与原Death3D_buffactivate已替换。素材库audio-review-1106保留重新解码源件及旧正式文件，W五个声音重新解码后与正式PCM一致。源事件、媒体编号、加工及哈希见[event_manifest.json](event_manifest.json)和[原版增益清单](../../original_gain_manifest.json)。

[草间人音频](../../../../docs/units/audio/scarecrow.md) · [远古恐惧音频](../../../../docs/units/audio/fiddlesticks.md)。
