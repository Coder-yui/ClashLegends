# 训练木桩 · 原版音频

[返回建筑卡](../target_dummy.md) · [总索引](../README.md)

| 时机 | 原版事件 | 变体 |
| --- | --- | --- |
| 出生 | Play_sfx_practicedummy_spawn | 2 |
| 受击 | Play_sfx_practicedummy_onhit | 4 |
| 死亡 | Play_sfx_practicedummy_death | 3 |
| 余震开始 | Play_sfx_Perks_Resolve_Aftershock_OnBuffActivate | 3 |
| 自然到期爆炸 | Play_sfx_Perks_Resolve_Aftershock_OnBuffDeactivate | 3 |

全部从本地Common.wad.client音频库解码，0dB原始相对音量，无强制归一化。受击声使用真实存活受击的节流事件；致死只播死亡。余震启动声2.5秒，瞬时增益不受动作取消；死亡/清场应清理单位持有音轨。凝滞到期不发爆炸声。出生与死亡使用现有通用生命周期。

木桩没有普攻或移动声。未发现独立部署语音，出生使用原版音效；不拿英雄台词替代。工作台可试听15个变体，实战录音和事件证据见交付报告；主观混音听感仍待用户确认。

[音频来源清单](../../../assets/audio/units/target_dummy/source_manifest.json)
