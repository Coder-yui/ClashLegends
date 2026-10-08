# 爆破酒桶 · 音频

[返回卡牌](../explosive_cask.md)

| 时机 | 原版事件 | 变体 / 增益 |
| --- | --- | --- |
| 酒桶正式发射 | Play_sfx_Gragas_GragasR_OnCast | 1 / 0dB |
| 权威抵达爆炸（含空放） | Play_sfx_Gragas_GragasR_boom | 4个随机变体 / 0dB |

基础与强化复用原版R音效；无独立在途循环事件，有意不添加无关声音。暂停和清场由全局音频管理器处理；空放仍爆炸，不额外逐目标重复播放。来源、事件与PCM输出哈希见[清单](../../../assets/audio/spells/explosive_cask/source_manifest.json)。

[试听施放](../../../assets/audio/spells/explosive_cask/cast.wav) · [试听爆炸](../../../assets/audio/spells/explosive_cask/boom_1.wav)

本轮从更新源包使用 wwiser -gv=0dB 重新生成事件并重新解码，未复用旧自动增益 WAV。实际运行已触发并录音；主观听感待用户试听确认。
