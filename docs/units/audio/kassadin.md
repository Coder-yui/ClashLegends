# 虚空行者声音

[返回虚空行者](../kassadin.md) · [总索引](../README.md)

基础皮肤原版音频，wwiser显式0dB主增益，保留事件内增益，最多三个变体；不会按普攻速度变调。

| 时机 | 声音 |
| --- | --- |
| 部署 | 客户端中文选人语音38，原OGG不重编码，按客户端语音统一补偿-13.5dB |
| 普攻1/2出手 | KassadinBasicAttack / KassadinBasicAttack2 OnCast |
| 普攻1/2真实命中 | 对应OnHit事件，分段映射 |
| R起手 | RiftWalk_OnCast |
| R落地 | RiftWalk_buffactivate，与原版appear粒子soundOnCreateDefault对应 |
| 死亡 | 中文Death3D，超过1.5秒才按统一淡出处理 |

详细来源、事件ID、源TXTP与SHA256见assets/audio/units/kassadin/event_manifest.json。原音频库没有独立死亡SFX事件，使用死亡语音；已接入中文部署语音。素材可解码及实际事件派发不等于用户听感认可。
