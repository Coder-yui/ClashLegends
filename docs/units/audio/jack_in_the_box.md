# 惊吓魔盒声音

[返回惊吓魔盒](../jack_in_the_box.md) · [单位索引](../README.md)

来源为本地Shaco基础皮肤SFX事件，wwiser显式-gv=0dB，vgmstream重新解码，不归一化、不加固定增益。每个事件保留三个随机变体；激活声由破隐和主动共用相同文件。

| 时机 | 原事件 | 处理 |
| --- | --- | --- |
| 部署开始 | JackInTheBox_OnCast | 完整0.62–0.87秒 |
| 首次破隐 / 主动命中 | JackInTheBox_BuffActivate | 完整1.49–1.97秒 |
| 每枚普攻发射 | ShacoBoxSpell_OnMissileLaunch | 完整0.97秒 |
| 实际弹体命中 | ShacoBoxSpell_OnHit | 完整1.04秒；未命中不播放 |
| 建筑死亡 | JackInTheBox_OnBuffDeactivate | 完整1.63–1.97秒；建筑消失声不套普通单位1.5秒裁剪 |

没有独立攻击起手声与建筑语音，未借用小丑英雄的普攻、部署或死亡语音；无待机持续音。使用公共短音池与混音总线，清场清理所有播放器，暂停跟随比赛暂停。来源媒体、哈希和加工在assets/audio/units/jack_in_the_box/event_manifest.json及全局原增益清单登记。

实机触发与混音记录见[本次交付](../../deliveries/2026-11-03_惊吓魔盒新卡.md)。最终听感仍需用户试听确认。
