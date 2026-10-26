# 庇护清泉音频

[返回庇护清泉](../pool_of_reflection.md)

| 场景 | 原版事件 |
| --- | --- |
| 落地 | Play_sfx_Hwei_HweiWW_OnCast |
| 清泉持续 | Play_sfx_Hwei_HweiWW_AoE_buffactivate |
| 清泉结束 | Stop_sfx_Hwei_HweiWW_AoE_buffactivate |
| 获得清泉盾 | Play_sfx_Hwei_HweiWWShield_OnBuffActivate |
| 清泉盾失效 | Play_sfx_Hwei_HweiWWShield_OnBuffDeactivate |

基础皮肤原事件图经wwiser显式0dB主增益、vgmstream重新解码；每事件至多3变体。区域持有持续声，3秒结束播放Stop尾音；暂停和清场使用现有生命周期。护盾持续声由受盾单位持有并跟随，刷新不重播，失盾立即停止并播放失效声；暂停、死亡和清场使用统一持续层生命周期。无英雄语音。逐文件来源及哈希见assets/audio/units/pool_of_reflection/event_manifest.json。

本项目对获得/持续护盾事件`pool_shield:sustain`额外衰减6dB；三条源WAV重新解码PCM比对一致、未加增益，保持原文件，只调整播放音量。区域、施法、消失音不变。
