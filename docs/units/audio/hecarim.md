# 战争之影音频

[返回战争之影](../hecarim.md) · [音频流程](../../AUDIO_INTEGRATION.md)

| 时机 | 原事件 |
| --- | --- |
| 部署语音 | “面对死亡。”（W台词层）、“冲破他们的阵型。”（Attack2DGeneral r2）、“我从不休息。”（Move2DStandard r3） |
| 旋斩出手 / 真实命中 | HecarimRapidSlash_OnCast / HecarimRapidSlash_hit |
| 突进开始 / 真实命中 | HecarimRampAttack_OnCast / HecarimRampAttack_OnHit |
| W施放 / 持续 / 结束 | HecarimW_OnCast / OnBuffActivate / OnBuffDeactivate |
| 死亡音效 / 中文死亡语音 | Death3D_cast / Death3D |

每个独立池最多3个变体。突进不重复播放Q命中声；空挥、致盲或免疫不伪造突进命中声。W持续声跟随增益状态，不由普攻动画结束；冰冻取消、死亡和清场停止。走路声音有意不接。

wwiser明确使用-gv=0dB，vgmstream重新解码，保留事件层叠增益，不归一化。死亡音效和死亡语音超过1.5秒均裁至1.5秒，前1秒原增益、后0.5秒线性淡出。来源、文件哈希与处理见[声音清单](../../../assets/audio/units/hecarim/event_manifest.json)。运行录音、事件与试听边界见[本次记录](../../deliveries/2026-10-22_战争之影新卡.md)。

部署池固定以上三句。W台词选择媒体37208729，保留-13 dB原事件增益，移除仅适用于W的2.5秒等待及随机吼声叠层；攻击/移动台词保留各自原事件增益，不归一化。原部署池另外两条移动语音已移出运行资源，源件与筛选过程留在本机素材库。
