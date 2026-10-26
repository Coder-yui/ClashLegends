# 攢聚雷音频

[返回攢聚雷](../severing_bolt.md)

| 时机（正式施放起） | 原版事件 |
| --- | --- |
| 0.5秒（施法完成，与预警同时） | HweiQW_OnCast |
| 0.5秒 | HweiQW_AoE_warning |
| 1.5秒 | HweiQW_AoE_explode |

三个阶段均为基础皮肤完整事件，每组3个随机变体；爆炸为落地声，空放也播放，不伪造命中声。原事件增益，wwiser显式0dB、重新解码，不逐文件归一化。走Combat总线混音；暂停与清场由统一音频管理器处理。

[施放试听](../../../assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_oncast_r1.wav) · [预警试听](../../../assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_aoe_warning_r1.wav) · [落雷试听](../../../assets/audio/units/severing_bolt/play_sfx_hwei_hweiqw_aoe_explode_r1.wav)

逐变体源TXTP、时长、媒体与哈希见资源目录event_manifest.json。最终试听状态见本次交付记录。

## 原版事件复核

原Wwise预警事件是3选1的单次随机容器（sLoopCount=1、bIsContinuous=0），不是应当循环的报警声；三个完整音轨长1.30/1.20/1.27秒。粒子声明为soundPersistentDefault，但源导出的QW事件中未发现独立Stop事件，不能据此推断落雷时必须硬切。当前保留完整原事件及自然尾音，不拉伸、剪短或在落雷时强制停止；预警与落雷短暂重叠不单独视为故障。施法音1.5秒，落雷音3.67/3.40/3.00秒，保持各自原事件增益。

时序还参考[Riot官方QW演示](https://www.leagueoflegends.com/en-us/event/hwei-abilities-rundown/)；源BIN给出0.5秒施法及1秒Delay，当前按此前奏和预警顺序运行。官方演示仅为视觉顺序核对，未作为当前客户端音频停止语义的逐帧证明。

官方演示音轨与本机源音交叉相关：OnCast r3在约0.5912秒、warning r1在0.6126秒、explode r3在1.6249秒匹配；两段前置声相差约21毫秒，预警到落雷约1.012秒。由此将OnCast从前奏开始改接spell:launch（0.5秒），在20Hz精度下与预警同Tick派发。视频版本、压缩与混音不支持样本级完全等价结论。
