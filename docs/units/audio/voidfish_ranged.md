# 远程虚空鱼音频

[返回单位](../voidfish_ranged.md) · [单位索引](../README.md)

- 出生：复用虚空鱼原版BelvethRMinionConverter出生声音，生成时播放一次。
- 出手：BelvethRMinion_cast_ranged，原动画第11帧节点；映射后约0.36秒，配置在发射前0.10秒播放。
- 命中：BelvethRMinion_hit_ranged，在真实弹体命中时播放，来源死亡后仍由在途弹体保留音频身份。
- 死亡：复用虚空鱼原版死亡变体。
- 再生：自定义技能未找到独立对应原版事件，不额外添加施法声音；新鱼生成会正常播放出生声。无部署语音与走路声。

远程两事件从Belveth.wad.client原版BNK重新生成，wwiser显式-gv=0dB，浮点解码转PCM16，无归一化或额外增益。详情见assets/audio/units/voidfish_ranged/event_manifest.json。实际试听结果见本次改动记录。
