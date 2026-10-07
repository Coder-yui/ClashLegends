# 永恒梦魇音频

[返回永恒梦魇](../nocturne.md) · [单位索引](../README.md)

| 时机 | 来源 |
| --- | --- |
| 部署 | 本地客户端zh_CN champion-choose-vo/56.ogg |
| 普通出手/命中 | NocturneBasicAttack、NocturneBasicAttack2对应原版事件 |
| 强化攻击出手/命中 | NocturneUmbraBladesAttack对应原版事件 |
| 开盾 | NocturneShroudofDarkness_OnCast |
| 死亡 | Nocturne_Death3D_cast，沿用通用死亡包络 |

基础皮肤SFX按wwiser -gv=0dB生成、vgmstream重新解码，不逐文件归一化；播放补偿0dB。来源变体与哈希见assets/audio/units/nocturne/event_manifest.json，部署为原始OGG。

实战已运行并录音，出手、命中和开盾事件有实际播放日志。未作人工听感验收，不能把日志与波形视作试听通过。护盾成功抵挡/自然结束的独立音效尚未接入：源包Buff激活事件含原版攻速增益语义，目前只接确切的开盾事件，避免混用。
