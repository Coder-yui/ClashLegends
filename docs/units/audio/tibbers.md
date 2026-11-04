# 提伯斯音频

[单位索引](../README.md) · [提伯斯](../tibbers.md) · [空投熊音频](airdrop_bear.md)

两套普攻分别映射BasicAttack和BasicAttack2的OnCast/OnHit；出手和真实命中分开，取消与空挥不伪造命中。每个命中池最多3变体，出手各1个。

两组事件的解码PCM相同，已合并4份重复WAV；事件仍分别配置，清单保留equivalent_sources。当前共9个唯一WAV，未跨不同音色或不同事件语义借用替代。

死亡音效为AnnieR_death_buffactivate，依据AnnieTibbers动画图Death.Audio_Death的显式绑定确定，不能仅按事件名误认为增益音。超过1.5秒者按项目规则保留前1秒、末0.5秒线性淡出。无独立提伯斯死亡语音，未替代为安妮语音。

强化常驻火圈使用AnnieR_buffactivate_loop（2变体）持续层，普通提伯斯不播放。声音跟随单位；暂停保留，凝滞停播、解除后恢复，死亡和清场停止。源事件增益保持0dB后期补偿。逐文件来源与加工记录见assets/audio/units/tibbers/event_manifest.json。

强化落地的狂暴获得音由[空投熊法术事件](airdrop_bear.md)负责，只播一次；不会因单位快照初始已带增益而漏播。动画图死亡节点明确绑定当前死亡事件。未绑定出生动画，因此不额外添加出生动作声音；移动脚步按项目约定不接。
