# 沙漠玫瑰声音

[返回沙漠玫瑰](../samira.md) · [音频流程](../../AUDIO_INTEGRATION.md)

基础皮肤SFX与zh_CN语音，wwiser显式-gv=0dB，每个声音池最多3个变体；未逐文件归一化。来源、哈希、死亡裁剪在[素材清单](../../../assets/audio/units/samira/event_manifest.json)。

| 时机 | 声音 |
| --- | --- |
| 部署 | Move2DStandard中文语音三选一：①啊，一朵沙漠中怒放的玫瑰。②危险怕我才对。③每个女孩都可能成为女王。 |
| 枪普攻 | BasicAttack/BasicAttack2各自起手、真实离弦与实际命中 |
| 刀普攻 | BasicAttackMelee/Melee2各自挥刀和命中；无发射声 |
| 满评分 | RReadyBuff_OnBuffActivate |
| R | R_OnCast起手，R_OnBuffActivate持续层，随动作结束、取消或死亡停止 |
| 死亡 | 仅保留Death3D_cast音效；death:voice按用户要求有意移除。音效超1.5秒者前1秒原增益，后0.5秒淡出 |

已在实际工作台触发并录制混音，覆盖双方普攻、R与冰冻/死亡中断。当前代理无法听取音频输入，不能将波形、播放或事件日志视为主观听感验收；部署台词选择、响度和衔接仍待用户试听。R没有独立结束事件，沿生命周期停止持续声，不用其他技能声音补齐。
