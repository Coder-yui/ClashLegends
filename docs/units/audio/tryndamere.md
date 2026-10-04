# 蛮族之王声音


> 客户端部署语音混音例外（2026-10-04）：`deploy_1.ogg` 固定播放 -18.5 dB。原素材不变，同池游戏内语音仍为 0 dB；此说明优先于下文历史的“全部播放补偿为 0 dB”。

> 当前增益基准（2026-10-04）：声音已从原版源事件重新导出，关闭工具 auto；文件制作增益和播放补偿均为 0 dB。裁剪、变速、包络及事件时机保留。本页旧调校段落中的额外 dB、统一制作余量属于重导前记录，已由此基准替代；原事件内部各层增益仍保留。详见[重导交付](../../deliveries/2026-10-04_原版增益音频重导.md)。


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
