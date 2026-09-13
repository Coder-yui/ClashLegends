# 2026-09-13 事件音频接入

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

来源只读：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/` 的英雄包、Common/Map11 共享音库。事件名按 FNV1 Wwise ShortID 与事件图核对，使用 wwiser TXTP、vgmstream-cli 渲染；保留来源增益。总清单：`assets/audio/event_expansion_manifest.json`；导入器：`tools/audio/import_event_audio_expansion.py`。未移动待开发队列素材。

| 对象 | 本次实际接入 | 尚未接入 |
| --- | --- | --- |
| 太阳圆盘技能 | 3190Active_OnCast 施放；3190Shield_OnBuffActivate 每个实际获盾目标 | 圆盘普攻、生成、死亡 |
| 小鬼 | YorickQ_summon 出生（5 变体），保留已有普攻/死亡 | — |
| 墓碑 | YorickW_OnHitLocation 部署；YorickW_death 死亡（4 变体） | 已找到墙体持续声，未实现生存循环层 |
| 治疗 | SummonerHeal_OnCast（3 变体），成功施法事件 | — |
| 四种小兵 | 双阵营出手/真实命中，两段攻击映射；红方攻城兵 OnMissileCast 随弹体创建 | 未核实独立生成/死亡和其余独立发射素材 |
| 防御塔 | 双阵营 MinionBasicAttack cast / missilelaunch / hit；break03 最终破碎 | 中间破损阶段没有对应玩法，不绑定；生成音未接入 |
| 水晶 | 双阵营 nexus_spawn 与 Nexus_death | 已找到 alive_loop，暂未引入常驻环境音层；水晶不能攻击，不配置攻击声 |

塔的 cast/launch 在现有权威发射时刻并行播放两层，不新增攻击前摇或改变计时；命中仍沿真实弹体结算，来源销毁后保留声音配置。系统建筑定义在 `scripts/data/world_audio.gd`，不加入可选牌库；摧毁声消费本地/快照的已去重 destroyed 表现通知。当前统一使用基础 MinionBasicAttack 事件，不区分英雄与小兵受击材质。

## 卡牌大师 Spell4 组织

工作台音频页按“仅试听”事件筛选，原始 SFX 分为：

- R1 Destiny_OnCast：首次开启命运。
- R1 Destiny_OnBuffActivate：命运状态生效的声音层。
- R1 Destiny_OnBuffDeactivate：命运状态结束。
- R2 Gate_OnBuffActivate：第二段传送引导。
- R2 Gate_marker：目标落点的完整声音。

这些是不同阶段，并非五个必须首尾拼接的片段。事件内还包含随机选择和多层声音；Stop_Destiny/Stop_Gate_marker 属于停止指令，没有单独 WAV。工作台提供 2 / 1 / 3 / 3 / 3 个外层导出变体，并非穷尽嵌套随机组合。英雄 VO 未加入本次五组 SFX 试听。当前实战仍使用既有 1.75 秒压缩 Gate_marker，不随试听目录改变。

## 验证

完整 mechanics 通过，覆盖盾声按目标、敌军静音、阵营配置校验、死后来源和系统音频资源加载。`tools/demos/event_audio_review.gd` 实际渲染工作台/护盾并录下混音，输出 `/tmp/clash-event-audio/`；日志确认治疗、墓碑、小鬼、双方小兵实际触发。`tools/demos/event_audio_network_review.gd` 支持 host/join 检查范围护盾的可靠卡牌事件。

实际运行录音不等于主观听感验收：响度、并发盾声和尾音仍需人工试听确认。未支持/缺素材事件如上表，不能将本轮称为全事件完成。

## 试听后的最终调整

- 卡牌大师：1.3 秒预部署 + 0.45 秒实际部署；声音仅保留原声前 1.75 秒，取消时间压缩。原声试听目录不变。
- 太阳圆盘 shield:applied：获盾目标坐标发声，额外 −24 dB；施放层不变。
- 小兵保持原值。核实的蓝方出手事件 TXTP 增益：近战 −59 dB、远程 −57 dB、攻城 −52 dB、超级兵 −49 dB。它们是事件图导出增益，不是游戏最终响度或声压级；本项目空间衰减、总线与 LoL 的完整实时混音不同。
- 水晶：出生声只在模型配置的 2.5 秒 spawn_duration 内播放，最后 0.25 秒淡出；接着播放原版 nexus_alive_loop，额外 −30 dB。死亡立即停止出生/待机，再播放既有死亡声；销毁和换场清理独占播放器，重绑不重播出生。不改出生动画/权威状态。待机片段按结束续播，未声称样本级无缝循环。
- 核验：完整 mechanics、原声逐采样比对；实际渲染录音见 /tmp/clash-nexus-audio 和 /tmp/clash-tf-deploy-175。最终主观响度仍由用户实战复听。

## 水晶动画重建与护盾取消

太阳圆盘 shield:applied 不再配置；保留施放声。水晶恢复原表保持/出生/待机序列与 Base/Destroyed 遮罩，取消旧出生/死亡强制压缩。保持 2.5 秒是项目表现选择，出生约 5.17 秒、死亡约 8 秒为导入原片时长；原始帧调度语义未完全复刻。死亡改用完整原版事件，待机保持额外 −30 dB。详见 assets/towers/nexus/README.md 与本目录 nexus_animation_source.txt。
