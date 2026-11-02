# 藤蔓鞭击者 · 声音

[← 总览](../vine_lasher.md)

| 时机 | 原版事件 |
| --- | --- |
| 部署 | ZyraEPlant OnBuffActivate，3变体 |
| Attack1出手 / 命中 | ZyraEPlantAttack OnCast / OnHit，各3变体 |
| Attack2出手 / 命中 | ZyraEPlantAttack2 OnCast / OnHit，各3变体 |
| 死亡 | ZyraEPlant OnBuffDeactivate，1变体 |

16个WAV来自婕拉基础皮肤原始BNK，通过wwiser显式0dB、vgmstream重新解码，保留源增益。死亡按通用1.5秒上限处理，超长素材尾部0.5秒淡出。植物无英雄语音；不接入远程弹体发射声音。

强化音效缺项：PlantEnrage的OnBuffActivate / buffactivate2 / OnBuffDeactivate引用的244/245/246节点在源BNK中缺失，当前不能生成声音，不用出生或大招本体声音替代。逐变体与源事件见[来源清单](../../../assets/audio/units/vine_lasher/event_manifest.json)。
