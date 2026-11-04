# airdrop_bear 音频映射

安妮基础R施法与落地点；不使用安妮语音。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `spell:cast` | `Play_sfx_Annie_AnnieR_OnCast` |
| `spell:enraged` | `Play_sfx_Annie_AnnieR_tibbers_enraged_buffactivate`（仅强化落地） |
| `spell:impact` | `Play_sfx_Annie_AnnieR_OnHitLocation` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。
