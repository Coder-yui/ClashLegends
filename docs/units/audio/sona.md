# 琴瑟仙女声音

[返回琴瑟仙女](../sona.md) · [返回总索引](../README.md)

| 时机 | 已接入来源 |
| --- | --- |
| 部署 | 中文客户端英雄选择37原始OGG，播放补偿−12.5dB |
| 普攻起手 / 发射 / 命中 | SonaBasicAttack OnCast / OnMissileLaunch / OnHit，各至多3变体 |
| 治疗启动 | SonaW OnCast，3变体；部署完成2秒后首次起奏，后续每5秒周期成功启动时起奏 |
| 治疗持续 | SonaAmbientWSound OnBuffActivate；跟随来源，每轮持续3秒；到期、凝滞、死亡和清场停止 |
| R起手 / 发射 / 命中 | SonaR OnCast / OnMissileLaunch / OnHit |
| 死亡音效 / 死亡语音 | 缺素材：基础皮肤事件表未声明，对Death3D显式解析无结果 |

权威命中派发命中声；空放和失效弹体不伪造命中。原事件增益保留，wwiser显式0dB，未归一化；持续音复用公共暂停/清场规则。没有走路声音，不使用Q/E/强化普攻或无关语音补位。

[逐文件来源](../../../assets/audio/units/sona/event_manifest.json)；实际试听与验证结论见[本次记录](../../deliveries/2026-11-06_琴瑟仙女新卡.md)。
