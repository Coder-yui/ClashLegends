# 虚空先知音频

[返回虚空先知](../malzahar.md)

| 当前动作 | 接入与变体 |
| --- | --- |
| 普攻出手 | 原版 OnCast，3 个变体，在攻击起手播放；Attack1/2 共用同一源池 |
| 弹体发射 | 原版 OnMissileLaunch，3 个变体，在真实创建弹体时播放 |
| 真实命中 | 原版 OnHit，3 个变体，取消或未命中不伪造播放 |
| 死亡 | 原版 Death3D_cast 音效 3 个变体，走 Combat；按用户要求不接入 death:voice |
| R 引导 | 原版 R_OnBuffActivate，跟随 channel 停止 |
| R 区域 | 原版 RZone，2 个变体，区域独立持续 5 秒，清场/终局停止 |
| 被动与主动 W | 原版 W_cas 的创建声音，每批裂隙开启时一次 summon:start；9 种随机层组合，保留 4.5 秒自然尾音 |
| 部署 | 中文客户端选人语音 90.ogg，文件不改增益，固定播放补偿 −12.5 dB |

音效保留源事件节点增益，工具主增益及后期固定增益均为 0 dB，无归一化。死亡音效最多 1.5 秒，前 1 秒原增益，后 0.5 秒线性淡出。来源、处理和哈希见 `assets/audio/units/malzahar/source_manifest.json` 与 `spawn_source_manifest.json`；通用总线仍有动态压缩及限幅。

原版 Q、E、护盾被动和暴击未被当前卡牌采用，不接入其声音；走路声按通用约定不做。Portal_Start/End、VoidlingSpawn 与 Override 无独立创建音效声明，不把完整 W 声重复播放三次。虚灵自己的出手、命中与死亡见[虚灵音频](voidling.md)。

2026-10-14 已重新解码对比源 PCM 与声明的死亡包络，并补齐出手/发射分离；死亡语音按用户要求不接入；实际运行播放与最终人工听感验收分别记录，人工听感不以数据检查代替。
