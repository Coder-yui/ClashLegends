# 腐蚀法术 · 音频

[← 返回腐蚀法术](../corrosion.md) · [总索引](../README.md)

使用莫甘娜基础皮肤原版 `Play_sfx_Morgana_MorganaW_cast`。正式施法后开始播放，区域5秒到期后允许原版尾音自然播完；暂停时暂停，清场和终局立即清理。蓝红阵营复用原声音。

[试听正式W音效](../../../assets/audio/spells/corrosion/morgana_w_cast.wav)

源事件解码时长6.547188秒，直接使用原始解码WAV，不裁剪、不拼接、不变速、不变调；PCM16、44100Hz单声道、0dB额外增益。区域在5秒结束伤害与特效，音轨剩余约1.55秒自然收尾；声音归区域音频管理，不逐跳重播，清场立即停止尾音。

已检查基础皮肤及10份关联定义，当前只有源包可确认的W施法事件；没有另外伪造命中/结束事件。实际运行播放和混音录音已执行，最终听感仍待用户确认。[来源记录](../../../assets/audio/spells/corrosion/source_manifest.json)

[← 返回腐蚀法术](../corrosion.md)
