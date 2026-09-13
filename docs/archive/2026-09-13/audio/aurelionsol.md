> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# aurelionsol 音频映射

普攻为 Spell1 吐息，全部使用 Q；星落/天瀑使用 R/R2。首次落点/冲击波独立命中尚缺入口。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `continuous_attack:start` | `Play_sfx_AurelionSol_AurelionSolQ_OnCast` |
| `continuous_attack:sustain` | `Play_sfx_AurelionSol_AurelionSolQ_missilelaunch` |
| `continuous_attack:end` | `Play_sfx_AurelionSol_AurelionSolQ_buffdeactivate` |
| `active:sustain` | `Play_sfx_AurelionSol_AurelionSolR_OnCast` |
| `active_strong:sustain` | `Play_sfx_AurelionSol_AurelionSolR2_OnCast` |
| `death` | `Play_vo_AurelionSol_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## 2026-09-13 全面复核更新

当前完整覆盖与本次补项以[逐英雄音频复核](../research/hero_audio_completeness_audit.md)及本目录 manifest 为准；前文历史“未接入”说明已由本次结果替代。新增事件保留原音频层与增益，实战由真实状态/效果触发。
