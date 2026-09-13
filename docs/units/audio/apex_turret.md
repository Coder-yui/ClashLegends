# 尖端炮台 · 音频接入

[← 返回尖端炮台总览](../apex_turret.md) · [总索引](../README.md)

## 目前能听到什么

部署与死亡使用炮台自己的生成、销毁音效；引擎声只在待机时延续，受到控制时暂停，死亡或清场时停止。激光有发射、飞行和命中过程。

## 声音与试听

| 发生时机 | 已接变体 | 音量调整 | 试听示例 |
| --- | --- | --- | --- |
| 普通攻击出手 | 3 | -3 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_oncast_r1.wav) · [试听 2](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_oncast_r2.wav) |
| 普通攻击命中 | 3 | -5 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onhit_r1.wav) · [试听 2](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onhit_r2.wav) |
| 普攻发射 | 3 | 0 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onmissilelaunch_r1.wav) · [试听 2](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimertbluebasicattack_onmissilelaunch_r2.wav) |
| 死亡 | 3 | 0 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffdeactivate_r1.wav) · [试听 2](../../../assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffdeactivate_r2.wav) |
| 部署开始 | 3 | 0 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r1.wav) · [试听 2](../../../assets/audio/units/apex_turret/play_sfx_heimertyellow_heimerdingerqspawndestroyaudio_onbuffactivate_r2.wav) |
| 持续待机声 | 1 | 0 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimerdingerrqengineaudio_onbuffactivate.wav) |
| 穿透激光 · 命中 | 1 | 0 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimerdingerturretbigenergyblast_onhit.wav) |
| 穿透激光 · 发射 | 1 | 0 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimerdingerturretbigenergyblast_onmissilelaunch.wav) |
| 穿透激光 · 持续过程 | 1 | 0 dB | [试听 1](../../../assets/audio/units/apex_turret/play_sfx_heimertblue_heimerdingerturretbigenergyblast_oncast.wav) |

0 dB 表示不额外加减音量，不代表所有原声听起来一样响。表中给出代表性试听，完整原始素材仍保留在来源记录中。

## 使用边界与待补项

当前主要事件没有已确认缺项；英雄本人的强化技能语音不适用于这座炮台。

## 怎么听

在开发工作台选中对象，先用上面的链接了解素材，再到实战页观察同一动作的出手与命中。持续声音还要检查中断、死亡和清场后是否及时停止；蓝红版本分别检查。

## 素材来源

- [来源与处理记录](../../../assets/audio/units/apex_turret/README.md)

[← 返回单位总览](../apex_turret.md)
