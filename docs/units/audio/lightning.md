# 大型电击法术 · 音频

[返回总览](../lightning.md) · [总索引](../README.md)

使用LoL符文电刑本体事件 `Play_sfx_Perks_Domination_Electrocute_OnBuffActivate` 的3个原始随机变体，每次实际落雷播放一次，不重复播放施法声。电击空放仍播放中心落雷声音，大型电击该段无目标则静音。暂停、清场遵循全局音频系统。

2026-10-08从原始TXTP/BNK重新导出，wwiser主增益0dB，保留事件内部各层增益，vgmstream浮点解码后转PCM16、单声道44100Hz。未裁剪、归一化或额外增益，播放补偿0dB。来源和哈希见[音频清单](../../../assets/audio/original_gain_manifest.json)。运行录音与触发次数已验证；当前工具无法听取音频输入，主观听感未标记为已验收。
