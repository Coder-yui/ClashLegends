# 荆棘喷射者 · 声音

[← 总览](../thorn_spitter.md)

| 时机 | 来源 |
| --- | --- |
| 出生 | ZyraQPlant OnBuffActivate，3变体 |
| 普攻起手 | ZyraQPlantMissile OnCast，3变体 |
| 尖刺发射 | ZyraQPlantMissile missilelaunch，3变体 |
| 真实命中 | ZyraQPlantMissile OnHit，3变体 |
| 死亡 | ZyraQPlant OnBuffDeactivate，1变体 |

均来自婕拉基础皮肤银行，以wwiser显式0dB和vgmstream重新解码，保留原事件增益。植物不使用婕拉英雄部署或死亡语音。死亡声音按通用1.5秒上限检查。

**强化声音缺项**：基础皮肤的PlantEnrage OnBuffActivate / buffactivate2 / OnBuffDeactivate事件存在，但动作分别引用缺失的244、245、246节点，当前源包无法产生声音图。没有用大招本体音或出生音代替。已生成并播放实战录音，含双方连续普攻、强化窗口与死亡；听感仍待用户验收，不能以事件检查代替听感确认。

文件、源事件与加工见[来源清单](../../../assets/audio/units/thorn_spitter/event_manifest.json)。
