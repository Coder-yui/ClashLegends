# 璐璐 · 音频

[← 返回璐璐](../lulu.md) · [总索引](../README.md)

| 时机 | 当前配置 |
| --- | --- |
| 普攻弹体发射 | 原版LuluBasicAttack2_OnMissileLaunch，3个变体，-5dB |
| 真实普攻命中 | 原版LuluBasicAttack2_OnHit，3个变体，-5dB；来源死亡后仍沿弹体来源播放 |
| 狂野生长起手 | 原版LuluR_OnCast，3个变体，0dB；不等于增益成功 |
| 死亡 | 原版Death3D_cast，1个音效，-3dB |
| 部署语音 | “见到你很高兴。”、“我建议滑着走。”、“大鼻子露珠。”三选一随机，0dB Voice总线 |
| 行走 / 周期召唤 | 有意静音；召唤出的皮克斯使用自身既有攻击音频 |

没有持续音轨；取消、死亡与清场沿既有短音预算和动作生命周期处理。未配置原版R结束声音，因为本卡增益不会计时结束。

[来源清单](../../../assets/audio/units/lulu/source_manifest.json) · [试听大招](../../../assets/audio/units/lulu/play_sfx_lulu_lulur_oncast_r1.wav) · [返回璐璐](../lulu.md)
