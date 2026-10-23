# 时间刺客音频

[返回时间刺客](../ekko.md)

基础皮肤原始Wwise事件，wwiser显式0dB生成，vgmstream重新解码，保持原有事件层次。每个独立池最多3个变体。部署固定使用中文台词“让我再重复一次。”，取自原始攻击指令事件 `Play_vo_Ekko_Attack2DGeneral` 第5变体（媒体780490105）；沿用事件增益，不额外归一化。

| 游戏事件 | 来源 |
| --- | --- |
| 三套普攻出手 / 命中 | EkkoBasicAttackP1、EkkoBasicAttackP2、EkkoBasicAttackP3的OnCast / OnHit |
| 每个目标仅一次第三击 | EkkoPassive_hit |
| R起手 / 回溯 / 落地 | EkkoR_OnCast / EkkoR_buffactivate / EkkoR_buffdeactivate |
| R中文语音 | Play_vo_Ekko_EkkoR_cast3D |
| 部署语音 | Play_vo_Ekko_Attack2DGeneral 第5变体：“让我再重复一次。” |
| 死亡音效 | Death3D_cast；death:voice按用户要求不配置 |

出手与真实命中分开，拒绝命中不播放命中声。死亡音效检查1.5秒上限，超长保留前1秒并在后0.5秒淡出。来源、时长和哈希见assets/audio/units/ekko/event_manifest.json与全局原增益清单。没有接入Q/W/E声音；步行不发声。实际运行记录及听感验收状态见交付记录。
