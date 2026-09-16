# 峡谷先锋音频

[← 峡谷先锋](../rift_herald.md) · [总索引](../README.md)

已接入：部署、两段普攻出手/命中、冲撞准备、起冲、路径挤压命中、建筑撞击、旋转拳吼声/释放/命中、死亡。来源为本地LoL Map11.wad.client原始Wwise事件银行，保留事件层叠和随机变体，不做逐文件归一化。

[打开本批试听台](http://127.0.0.1:18779/)；关闭后可运行 `python3 tools/dev.py audio --manifest "ClashLegends-开发素材库/02-候选讨论/峡谷先锋与虚空蠕虫全量音频/catalog.json" --port 18779`。游戏内在卡牌开发工作台选择本单位试听与实战检查。

先锋准备声音由动作持续层持有，被控制打断、死亡或清场时停止，重新准备时重播。命中音效只在真实命中结算后触发；旋转拳效果节点只播放SpinAttack_hit；SpinAttack_vox在动作0.31秒、SpinAttack_cast在0.87秒启动，1.57秒伤害节点不再重复释放声。普通死亡声音最多1.5秒，保留前1秒，最后0.5秒线性淡出。

未移植走路声音、原版载人操纵/眼睛弱点事件；这些机制未使用。 原版粒子附带的其他音层未全部复刻。已运行双方实战录音；最终混音喜好仍待用户试听确认。

[逐文件来源清单](../../../assets/audio/units/rift_herald/event_manifest.json)

## 全量原声试听

[按事件分组试听](http://127.0.0.1:18779/)：本地Map11包内riftherald、riftherald_milkshake和horde_mini三组SFX银行，共68类事件、137条可试听输出（含条件分支和24条生成器标记的重复/别名输出，非137条独立录音）。先锋64类121条；蠕虫4类16条，其中死亡4变体归为一类。全量候选未裁剪，游戏仍只接当前动作需要的声音。

7个事件未恢复语义名，已按真实事件ID分组保留，未猜测用途；Stop等无声控制事件没有伪造音频。此处“全量”限定于已核对的本地源包三组银行，不代表LoL所有历史版本。

[完整时长与触发对照](../animations/rift_herald.md#时长与声音对照)

动作对应：Attack1 → BasicAttack_OnHit；Attack2 → BasicAttack2_OnHit；Dash_Hit → dash_hit；spinningpunch → SpinAttack_hit。原始Wwise中SpinAttack_hit与BasicAttack2_OnHit存在共用底层素材，保留原事件映射，不为制造差异替换声音。准备2.5秒，眩晕/击退/冰冻打断时终止持续声而非仅暂停；重新准备重新播放。

普攻周期2.00秒，出手声随起手，原始对应命中声随0.50秒真实命中，声音不变调。旋转拳3.00秒，210伤害。沿途挤开地面单位保留原银行`Play_sfx_SRU_RiftHerald_charge_hit_minion`4变体，区别于建筑的`dash_hit`；只在沿途伤害实际命中后播放一次。
