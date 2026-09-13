> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# apex_turret 音频映射

使用大发明家基础皮肤声音库中 HeimerTBlue 大炮台的 SFX；部署与死亡使用 Q 炮台 HeimerTYellow 的 Spawn/Destroy SFX，不使用英雄语音。当前 19 个接入 WAV，原始事件、媒体、源路径、处理和哈希见 event_manifest.json。

| 用途 / cue | 原始事件 | 变体 / 时序 |
| --- | --- | --- |
| 部署 `deploy:start` | `Play_sfx_HeimerTYellow_HeimerdingerQSpawnDestroyAudio_OnBuffActivate` | 3 选 1，约 1.01 / 1.12 / 1.05 秒；生成时一次，重绑不重播 |
| 死亡 `death` | `Play_sfx_HeimerTYellow_HeimerdingerQSpawnDestroyAudio_OnBuffDeactivate` | 3 选 1，死亡一次；约 1.50 / 1.33 / 1.50 秒 |
| 待机 `idle:sustain` | `Play_sfx_HeimerTBlue_HeimerdingerRQEngineAudio_OnBuffActivate` | 12 秒事件预览片段，保留源 -26 dB 增益，待机持续续播 |
| 普攻 swing `attack_swing` | `Play_sfx_HeimerTBlue_HeimerTBlueBasicAttack_OnCast` | 3 选 1；开始攻击前摇 |
| 普攻 launch `attack_launch` | `Play_sfx_HeimerTBlue_HeimerTBlueBasicAttack_OnMissileLaunch` | 3 选 1；0.55 秒实际创建弹体 |
| 普攻 hit `attack_hit` | `Play_sfx_HeimerTBlue_HeimerTBlueBasicAttack_OnHit` | 3 选 1；实际炮弹命中，不在发射时播放 |
| 激光 swing / 蓄能 `laser:sustain` | `Play_sfx_HeimerTBlue_HeimerdingerTurretBigEnergyBlast_OnCast` | 1 个 1.43 秒片段；动作开始，受控暂停、动作结束清理 |
| 激光 launch `laser:release` | `Play_sfx_HeimerTBlue_HeimerdingerTurretBigEnergyBlast_OnMissileLaunch` | 1 个 1.19 秒片段；施法后 0.45 秒出膛 |
| 激光 hit `laser:hit` | `Play_sfx_HeimerTBlue_HeimerdingerTurretBigEnergyBlast_OnHit` | 1 个 1.25 秒片段；真实弹体接触每个目标时播放，空击静音 |

待机引擎不再配置到 deploy:start。仅在部署结束、无攻击和无技能动作的待机状态播放；离开待机、死亡、销毁与换场停止，冻结/眩晕暂停。返回待机重新启动片段；不承诺 Wwise 样本级无缝循环。所有状态读取权威 Unit 或客户端 Snapshot，声音不驱动战斗。

来源：本机 LOL_Asset_Source 的 Heimerdinger.wad.client SFX 与 炮台基础皮肤事件；原包只读，外部选定成品复制到 assets，非待开发队列迁移。内部 en_US 路径来自中文 WAD 内命名，不代表英文音轨。wwiser v20260909 + 共享 init.bnk，vgmstream-cli -i 解码 PCM16 WAV，保留事件层与源增益，不归一化。生成/销毁原始 TXTP 位于 /Users/czh/Tools/lol-asset-tools/card_audio_batch/heimerdinger/txtp；tools/audio/import_apex_spawn_audio.py 可重导选定 6 个变体。此前选入的 QUlt 英雄语音已移除。

未发现独立命名的 RQ Spawn/Destroy，按用户确认复用 Q 炮台生成/销毁音；引擎仍使用 RQ 专属事件。死亡按项目既有规则处理：超过 1.5 秒保留前 1.5 秒，末 0.5 秒淡出；原始 TXTP / WAD 不改。未完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

2026-09-13 验证：mechanics 全部通过，包括部署去重、待机续播/攻击停止/冻结暂停/死亡清理、普攻三阶段、激光 0.45 秒真实出膛/沿途逐目标命中、空击与死亡取消。tools/demos/apex_audio_review.gd 实际运行并录音到 /tmp/clash-apex-audio；host/join 检查部署、待机、穿透命中与死亡事件。运行记录证明事件触发，最终主观听感仍需游戏内试听。
