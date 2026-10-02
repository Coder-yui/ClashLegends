# 蛮族之王声音

[返回蛮族之王](../tryndamere.md) · [单位索引](../README.md)

| 时机 | 当前接入 |
| --- | --- |
| 部署 | 随机三句：我的大刀早已饥渴难耐了。／开战吧。／这将会是场屠杀。独立Voice总线 |
| 普通挥刀 | BasicAttack/BasicAttack2 OnCast各4变体，按权威攻击段选择，前0.4秒待机不播放挥刀 |
| 普通命中 | 两种OnHit各4变体；未命中不播放 |
| 暴击 | CritAttack OnCast/OnHit各4变体，暴击使用独立声音池 |
| 大招 | 原版UndyingRage OnCast、OnBuffActivate持续声、OnBuffDeactivate结束声 |
| 死亡 | 中文Death3D三变体，1秒内收尾，末0.2秒淡出 |

第一句来自LeagueClient中文选人23.ogg；另两句分别为Attack2DGeneral的r4和r3。其余来源为本机Tryndamere.wad.client与Tryndamere.zh_CN.wad.client，通过既有Wwise事件解析工具渲染；33个正式WAV均使用PCM16，统一衰减2.216dB保留事件间相对增益并避免PCM削波。持续音由既有Buff所有者停止，暂停、死亡、清场不遗留播放器。

双方实际工作台运行已触发部署、普通/暴击、增益启停与死亡并录音。三句已按源事件与本地语音转写核对，并实际播放；用户尚未确认整体混音听感；不能将事件日志等同于主观听感通过。来源与哈希见[素材记录](../../../assets/audio/units/tryndamere/README.md)。
