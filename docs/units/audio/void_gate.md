# 兹若特传送门声音

[返回传送门](../void_gate.md) · [音频流程](../../AUDIO_INTEGRATION.md)

来源Map12.wad.client的NPC_Global_VoidGate_SFX_audio/events.bnk。旧Jade皮肤声明与实际银行事件经过Wwise ID核对，银行实际名称不带Jade前缀。

| 时机 | 原版事件 | 变体 |
| --- | --- | --- |
| 部署 | Play_sfx_S5_VoidGateSpawn_cast | 3 |
| 主动摧毁、受伤死亡、寿命结束 | Play_sfx_S5_VoidGateSpawn_deactivate | 1 |
| 出兽 | 虚空兽Play_sfx_S5_VoidSpawn_spawn_cast第一变体，在出生动作第23帧对应进度触发 | 1 |

wwiser显式-gv=0dB，浮点解码后转PCM16，无归一化或后期增益，游戏配置0dB。无部署语音；已核对的银行事件中没有可确认的独立吐出声与待机循环，出兽由新生虚空兽的原版出生音承接。原动画图另有spawn_spit_sound事件，但尚未建立它与当前银行具体音轨的可靠对应，不使用猜测音效替代。死亡、清场和暂停使用通用声音生命周期。来源、事件ID、TXTP与成品哈希见assets/audio/units/void_gate/event_manifest.json。

单只虚空兽通过deploy:start.action_time=23/34秒在现有1秒部署中派发，仍走通用声音池、预算、空间位置和去重；不在生成零帧提前播放。取消/死亡不补节点，晚到重建不补播历史节点。
