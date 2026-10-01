# 凝滞法术音频

[返回凝滞法术](../stasis.md)

| 时机 | 原版事件 | 当前接入 |
| --- | --- | --- |
| 水晶发射 | BardR_OnCast | spell:cast，3个随机变体 |
| 弹体飞行 | BardR_mis | spell:flight，2个随机变体；跟随弧线位置，抵达或清场停止 |
| 弹体抵达 | BardR_explo | spell:strike，3个随机变体；空放也播放 |
| 目标进入金身 | bardr_stasis_tar | stasis_target:sustain，2个变体；单次短触发音，不循环，状态提前结束也截断 |
| 金身持续阶段 | BardR_statisquiet_hit / BardR_statisfull_hit | 按用户要求全部移除，不再播放持续声 |
| 巴德动作前摇 | BardR_windup_cast | 按用户要求不接入 |
| 落点预警 | BardR_warn_oba | 按用户要求不接入 |

素材来自Bard基础皮肤BNK，经wwiser事件还原与vgmstream解码，保留原始增益。水晶发射、飞行与爆开为Combat 0dB，目标与金身层为Combat -6dB。OnCast保留为项目水晶发射声；项目没有巴德角色动作。

quiet/full及其变体已移出正式资源。仅保留约1.04秒目标进入音，正常播放一次，不循环或拉长到2/3秒；若状态提前解除则停止。暂停同步冻结，死亡、移除和终局清理。凝滞本身仍按2/3秒运行，不受声音长度影响。

沿用24个持续声部预算，飞行声独立使用世界声部上限。重复飞行事件不重播，清除飞行表现会清理声音。所有正式素材与处理见 `assets/audio/spells/stasis/source_manifest.json`。

已在实际图形场景运行发射、飞行、爆开及2/3秒金身起止检查；最终主观听感和密集目标混音仍待人工确认。
