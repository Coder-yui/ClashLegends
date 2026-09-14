# 墓碑 · 音频接入

[← 返回墓碑总览](../tombstone.md) · [总索引](../README.md)

## 目前能听到什么

部署后出现持续生存声，受控时暂停，死亡、销毁或清场时停止；使用“亡者集结”时在 Cast Start 播放一次技能音。召唤出来的小鬼播放小鬼自己的出生声，不把同一声音叠到墓碑上。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 死亡 | 4 | 0 dB | [试听 1](../../../assets/audio/units/tombstone/play_sfx_yorick_yorickw_death_r1.wav) · [试听 2](../../../assets/audio/units/tombstone/play_sfx_yorick_yorickw_death_r2.wav) |
| 部署开始 | 2 | 0 dB | [试听 1](../../../assets/audio/units/tombstone/play_sfx_yorick_yorickw_onhitlocation_r1.wav) · [试听 2](../../../assets/audio/units/tombstone/play_sfx_yorick_yorickw_onhitlocation_r2.wav) |
| 持续待机声 | 1 | 0 dB | [试听 1](../../../assets/audio/units/tombstone/play_sfx_yorick_yorickwwalllife_onbuffactivate_r1.wav) |
| 亡者集结施法开始 | 1 | 0 dB | [试听](../../../assets/audio/units/tombstone/play_sfx_yorick_yorickw_oncast_r1.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 使用边界与待补项

主动召唤现在使用 `Play_sfx_Yorick_YorickW_OnCast · r1` 作为墓碑本体的 Cast Start 音；新生成的小鬼仍有自己的出生声。掘墓人相关 Q/W/E/R 其他原始素材（含 W 墓墙候选）继续只放在[临时音频展台](http://127.0.0.1:18765/)试听。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/units/tombstone/README.md)

[← 返回单位总览](../tombstone.md)
