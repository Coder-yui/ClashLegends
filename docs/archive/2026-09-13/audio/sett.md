> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# sett 音频映射

四段左/右拳使用 BasicAttack/BasicAttack2 出手，命中按 BasicAttack/2/3/4 排列；普通/满豪意 W 分开。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Sett_SettBasicAttack_cast` |
| `attack_swing[2]` | `Play_sfx_Sett_SettBasicAttack2_cast` |
| `attack_swing[3]` | `Play_sfx_Sett_SettBasicAttack_cast` |
| `attack_swing[4]` | `Play_sfx_Sett_SettBasicAttack2_cast` |
| `attack_hit` | `Play_sfx_Sett_SettBasicAttack_OnHit` |
| `attack_hit_by_segment[1]` | `Play_sfx_Sett_SettBasicAttack_OnHit` |
| `attack_hit_by_segment[2]` | `Play_sfx_Sett_SettBasicAttack2_OnHit` |
| `attack_hit_by_segment[3]` | `Play_sfx_Sett_SettBasicAttack3_OnHit` |
| `attack_hit_by_segment[4]` | `Play_sfx_Sett_SettBasicAttack4_OnHit` |
| `active:sustain` | `Play_sfx_Sett_SettW_cast` |
| `active:hit` | `Play_sfx_Sett_SettW_hit` |
| `active_strong:sustain` | `Play_sfx_Sett_SettW_maxed_cast` |
| `active_strong:hit` | `Play_sfx_Sett_SettW_maxed_hit` |
| `deploy:start` | `Play_sfx_Sett_Respawn3D_buffactivate`（源声音前 1 秒，末 50ms 淡出） |
| `death` | `Play_vo_Sett_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

动画收尾核对：部署原速前 1 秒使用同名原始声音裁剪；普攻保留四段映射，命中不受混合时长影响；两种 W 命中声随共同 0.8 秒真实结算，cast sustain 在动作结束 / 打断时停止；死亡叫声自然结束，模型前 1.7 秒压到 0.8 秒不改变音高。实际运行录音位于 `/tmp/clash-card-audio/sett.wav`；事件和波形检查不能替代人工听感确认。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## 2026-09-13 全面复核更新

当前完整覆盖与本次补项以[逐英雄音频复核](../research/hero_audio_completeness_audit.md)及本目录 manifest 为准；前文历史“未接入”说明已由本次结果替代。新增事件保留原音频层与增益，实战由真实状态/效果触发。
