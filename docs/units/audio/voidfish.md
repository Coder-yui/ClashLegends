# 虚空鱼音频

[返回单位](../voidfish.md) · [单位索引](../README.md)

声音来自本地只读 `Belveth.wad.client` 的基础皮肤音效银行。使用 wwiser `-gv=0dB` 还原事件，先浮点解码再转为48kHz单声道PCM16，不归一化；制作与播放额外增益均为0dB，保留原事件内部层间增益。来源与逐文件加工见[清单](../../../assets/audio/units/voidfish/source_manifest.json)。

| 动作 | 原版声音及触发 |
| --- | --- |
| 出生 | `BelvethRMinionConverter_buffactivate_birth`；生成时播放一次，与部署锁无关。两层各有4个随机成员，第二层延后0.5秒；当前保留前3种完整组合，保留两层的-24/-20dB原事件增益。重绑不重复播放。 |
| 近战出手 | `BelvethRMinion_cast_melee`，媒体358266359；动作起点播放。 |
| 近战命中 | `BelvethRMinion_hit_melee`，媒体711132112；真实命中时播放。 |
| 死亡 | `BelvethRMinion_cast_death` 的两个随机成员，媒体580957980、421865323。时长约0.948/0.970秒，低于普通单位1.5秒上限，无需额外裁剪。 |

出生与死亡池由[远程虚空鱼](voidfish_ranged.md)及其单只、大军形态共用；远程出手、命中使用各自独立原版事件。没有虚空鱼部署语音，走路声有意静音，不使用女皇台词替代。

使用通用短音预算、暂停恢复与清场生命周期。原版Wwise总线、距离及RTPC动态混音未完整复现，0dB不代表与LoL实战响度相同。本次核查、补齐与试听边界见[改动记录](../../deliveries/2026-10-14_虚空鱼音频补齐.md)。
