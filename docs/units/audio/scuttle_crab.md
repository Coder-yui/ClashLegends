# 峡谷迅捷蟹：声音

[返回单位](../scuttle_crab.md) · [总索引](../README.md)

| 时机 | 来源事件 | 变体 / 停止规则 |
| --- | --- | --- |
| 部署 | SRU_Crab_spawn_cast | 1种，一次播放 |
| 建筑前舞蹈 | SRU_Crab_Sru_Dance | 2种，舞蹈期间循环，离开、受控、死亡或清场停止 |
| 死亡 | SRU_Crab_death_cast | 1种，原1.942秒截为1.5秒，最后0.5秒淡出 |
| 触角衔接跃起 | SRU_Crab_death_leap | 1种，死亡第1秒触发，完整1.207秒 |
| 治疗阵形成 | SRU_Crab_ward_cast | 1种，完整4.004秒，死亡第2秒展开时触发 |
| 谦卑 | RanduinsOmen_OnCast | 1种，原6.125秒完整尾音 |

来源为Map11的NPC_Map11_Crab_SFX及Common的Items_Global音频银行。wwiser显式使用`-gv=0dB`，保留原事件层增益，事件播放补偿0dB，无归一化。清单位于`assets/audio/units/scuttle_crab/source_manifest.json`。

没有普通攻击、命中或行走音。原版 leap_sound 已按原动画图绑定衔接动作，于第1秒触发，形成声于第2秒触发。河道加速音不用于纯治疗规则。实际运行录音已生成，最终听感待用户试听。
