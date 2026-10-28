# 终极闪光音频

[← 终极闪光](../final_spark.md) · [总索引](../README.md)

保留Lux基础皮肤R的空间组织：起点播放Play_sfx_Lux_LuxR_OnCast，中点播放Play_sfx_Lux_LuxRBeam_beammiddle，终点播放Play_sfx_Lux_LuxRBeam_beamend；三者从起手一起启动，事件自身包含0.9秒延迟的爆发层，不在伤害时重复启动。每组保留3个确定随机分支组合，原始随机层与事件增益保留，wwiser明确-gv=0dB，无归一化或额外固定增益。

本地R_tar没有独立命中音事件，不添加无来源的受击声；主动致盲复用通用视觉提示，不额外添加被动伤害音。清场与暂停沿用GameAudioManager生命周期。来源、TXTP、媒体集合、SHA256与加工信息见assets/audio/units/final_spark/manifest.json及全局原增益清单。素材解码与事件触发不等于完整LoL实时空间混音。
