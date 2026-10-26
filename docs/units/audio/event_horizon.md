# 扭曲空间音频

[返回扭曲空间](../event_horizon.md)

| 项目事件 | 小法师原版事件 | 时机 |
| --- | --- | --- |
| 施法 | VeigarEventHorizon_OnCast，3变体 | 公共出牌延迟结束 |
| 围栏持续 | VeigarEventHorizon_loop，2变体 | 成形时开始，区域有效期3秒后停止；清场立即停止 |
| 成功眩晕 | VeigarEventHorizon_buffactivate | 目标成功接受边界控制 |
| 黑暗物质预警 | VeigarDarkMatter_OnCast | 首次成功眩晕、锁定落点 |
| 黑暗物质落地 | VeigarDarkMatter_hit | 权威24Tick后落地，空落仍有地面爆炸声 |

来源为小法师基础皮肤SFX音频银行，wwiser明确`-gv=0dB`，vgmstream重新解码，未归一化或额外增益。8个正式文件及哈希在 `assets/audio/units/event_horizon/event_manifest.json`，增益清单同步维护。

一次性事件与区域持续声分别管理；无单位攻击、语音或死亡事件。可靠卡牌事件复制给两端，清场统一停止音频。实际运行记录与试听边界见本次交付记录。
