# 武器大师音频

[返回武器大师](../jax.md) · [单位索引](../README.md)

| 时机 | 原版声音 |
| --- | --- |
| 部署语音 | 中文客户端选人语音，原OGG，播放补偿-8dB |
| 部署动作 | Respawn3D |
| 两种普攻出手 | BasicAttack / BasicAttack2，各3个变体 |
| 普攻真实命中 | 对应BasicAttack / BasicAttack2命中事件，各1个当前材质分支 |
| E持续 | JaxE_OnBuffActivate，3个变体，随窗口结束、死亡或清场停止 |
| E自然结束 | JaxE_OnBuffDeactivate，3个变体；取消不伪造结束爆发 |
| E真实命中 | JaxE_hit，3个变体；空放、免疫不发命中声音 |
| 死亡音效 / 死亡语音 | Death3D_cast / 中文Death3D；分别播放，超过1.5秒裁剪并在最后0.5秒淡出 |

源包来自本机LOL_Asset_Source，wwiser显式-gv=0dB，重新解码，保留事件层增益；不逐条归一化。未知命中材质Switch仅取明确单一分支，不声称覆盖所有材质与嵌套随机。无走路声音；未接入Q/W/R声音。

文件与源TXTP、哈希及加工见[音频来源](../../../assets/audio/units/jax/event_manifest.json)。运行录音与验证状态见交付记录；人工听感验收与自动播放/录音检查分开。
