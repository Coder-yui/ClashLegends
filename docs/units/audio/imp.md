# 雾行者 · 音频接入

[← 返回雾行者总览](../imp.md) · [总索引](../README.md)

## 当前配置与触发入口

下表记录当前声音配置及预期触发节点，试听链接用于查看素材；不代表本次已逐项实机试听。实际触发、取消与听感分别验收，共通边界见[声音合同](../../status/PRESENTATION.md#音频按声音归属取消不能按整个单位静音)。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 普通攻击出手 | 1 | -3 dB | [试听 1](../../../assets/audio/units/imp/play_sfx_yorick_yorickq_ghoulattack_cast_r1.wav) |
| 死亡 | 3 | 0 dB | [试听 1](../../../assets/audio/units/imp/play_sfx_yorick_yorickq_ghoul_death_r1.wav) · [试听 2](../../../assets/audio/units/imp/play_sfx_yorick_yorickq_ghoul_death_r2.wav) |
| 出生 | 5 | 0 dB | [试听 1](../../../assets/audio/units/imp/play_sfx_yorick_yorickq_summon_r1.wav) · [试听 2](../../../assets/audio/units/imp/play_sfx_yorick_yorickq_summon_r2.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 试听台补充候选

本轮另放入 [临时音频展台](http://127.0.0.1:18765/) 对照：雾行者跳跃攻击 `Play_sfx_Yorick_YorickQ_GhoulAttack_jump` 三个变体，以及 `Play_sfx_Yorick_YorickQ_aggro` 低吼。它们都没有接入正式配置；出生、出手、死亡的全部当前变体也在展台中便于横向比较。

## 使用边界与待补项

普通攻击命中按当前决定暂时不用接入，未来可能重新处理；不会用原版跳跃声冒充命中声。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/units/imp/README.md)

[← 返回单位总览](../imp.md)
