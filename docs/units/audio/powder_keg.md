# 火药桶 · 音频

[返回火药桶](../powder_keg.md) · [总索引](../README.md)

| 事件 | 来源与行为 |
| --- | --- |
| 部署 | 船长原皮 Play_sfx_Gangplank_GangplankEBarrelLife_OnBuffCast，3个随机变体；替换E施放声 |
| 死亡爆炸 | Play_sfx_Gangplank_GangplankEBarrelExplosionSound_buffcast，事件ID 3466163195；3个变体 |
| 获得金币 | 复用迅捷蟹已接入金币提示的3个变体 |
| 受击 | Play_sfx_Gangplank_GangplankEBarrelLife_OnBuffDeactivate；用户原版实听确认为掉血声，3个随机变体用于受击Timer反馈 |
| 部署语音 | 桶没有角色语音，不附加船长对白 |

原始Gangplank.wad.client只读。事件增益保留，运行补偿0dB；超长爆炸尾音裁到1.5秒，末0.15秒淡出。爆炸事件通过Wwise FNV ID核对，未命名银行事件224为Life_OnBuffDeactivate（ID 1011790323），经用户实听确认后用于受击。完整来源及加工见 `assets/audio/units/powder_keg/event_manifest.json` 和原增益清单。

自然寿命连续扣血不逐帧发声；致死受击只播放爆炸。powderburn经用户实听确认为连续桶之间的火药传导，本项目不接入。

实际运行已记录部署/爆炸/金币触发及混音；自动录音不等于人工听感验收，最终听感仍待用户确认。
