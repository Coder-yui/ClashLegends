# soul_tentacle 音频映射

触手独立事件；拍地不要求命中。强化状态与死亡音仍待源定义核对。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Illaoi_IllaoiTentacleAttack_OnBuffCast` |
| `attack_hit` | `Play_sfx_Illaoi_IllaoiTentacleAttack_minion_hit` |
| `deploy:start` | `Play_sfx_Illaoi_IllaoiTentacleSpawn_buffactivate` |
| `attack:ground` | `Play_sfx_Illaoi_IllaoiTentacleAttack_Ground_Hit` |
| `active:cast` | `Play_sfx_Illaoi_IllaoiTentacleActive_OnBuffCast` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。
