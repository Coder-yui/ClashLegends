# 库奇音频

[返回库奇](../corki.md) · [音频流程](../../AUDIO_INTEGRATION.md)

| 时机 | 接入内容 |
| --- | --- |
| 部署 | 三句等概率随机：“王牌飞行员，申请出战。”“随时可以起飞。”“激情在燃烧。” |
| 普攻起手 / 发射 / 命中 | 原版CorkiBasicAttack OnCast / OnMissileLaunch / OnHit；Attack1与Attack2对应相同媒体，命中在真实结算后播放 |
| 火箭轰击起手 | MissileBarrage OnCast三变体 |
| 普通导弹释放 / 爆炸 | MissileBarrageMissile OnMissileLaunch / boom三变体 |
| 超级导弹释放 / 爆炸 | MissileBarrageMissile2 OnMissileLaunch / boom |
| 死亡 | 中文Death3D原声 |

锁定语音来自本地客户端zh_CN包的42.ogg；另两句来自英雄中文包的CorkiLoaded_cast r2、Move2DStandard r1，事件台词目录与本地转写交叉定位。普攻和技能重新以wwiser `-gv=0dB`生成事件TXTP，再解码为44.1kHz双声道16位WAV，保留事件衰减，不做自动增益或逐条归一化。原先TXTP使用auto，抵消了事件衰减；此前“保持原响度”的记录不准确。来源、哈希与事件见assets/audio/units/corki/source_manifest.json。

未添加行走/发动机持续循环或未实现Q/W/E声音。发射声作为有限单次声音自然衰减，不把来源死亡当在途弹体结束；命中音只在真实碰撞出现。清场统一停止。已在实际运行触发并录制双方普攻、两类导弹、冻结恢复和死亡；事件与录音检查不等于用户主观听感确认，最终听感待用户试听。

## 2026-10-04 响度复核

| 事件 | 源事件衰减（已烘焙到WAV） |
| --- | --- |
| 普攻起手 / 发射 / 命中 | −18 / −22 / −16 dB |
| 技能起手 / 普通导弹发射 / 爆炸 | −14 / −14 / −12.5 dB |
| 超级导弹发射 / 爆炸 | −10 / −9 dB |

这些声音的项目播放增益统一为0 dB，避免二次衰减；保留超级导弹比普通导弹更强的层次。修正后15个SFX文件峰值在−24.54至−11.23 dBFS之间，未检测到满幅削波。语音资源本次未改。原版完整实时RTPC、空间衰减、总线及动态混音未复刻，因此仅确认源事件静态增益恢复，不声称与LoL最终输出响度完全一致。
