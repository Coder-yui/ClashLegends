# ekko 音频映射

基础皮肤，三套普攻、被动第三击、R起手及落地；死亡语音来自zh_CN语言包。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Ekko_EkkoBasicAttackP1_OnCast` |
| `attack_swing[2]` | `Play_sfx_Ekko_EkkoBasicAttackP2_OnCast` |
| `attack_swing[3]` | `Play_sfx_Ekko_EkkoBasicAttackP3_OnCast` |
| `attack_hit_by_segment[1]` | `Play_sfx_Ekko_EkkoBasicAttackP1_OnHit` |
| `attack_hit_by_segment[2]` | `Play_sfx_Ekko_EkkoBasicAttackP2_OnHit` |
| `attack_hit_by_segment[3]` | `Play_sfx_Ekko_EkkoBasicAttackP3_OnHit` |
| `active:cast` | `Play_sfx_Ekko_EkkoR_OnCast` |
| `rewind:start` | `Play_sfx_Ekko_EkkoR_buffactivate` |
| `active:land` | `Play_sfx_Ekko_EkkoR_buffdeactivate` |
| `rewind:voice` | `Play_vo_Ekko_EkkoR_cast3D` |
| `passive:proc` | `Play_sfx_Ekko_EkkoPassive_hit` |
| `death` | `Play_sfx_Ekko_Death3D_cast` |
| `death:voice` | `Play_vo_Ekko_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。
