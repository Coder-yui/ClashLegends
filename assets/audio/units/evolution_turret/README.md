# evolution_turret 音频映射

H-28G普通炮台原版双普攻事件。修复复用Q生成声；无英雄语音。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_HeimerTYellow_HeimerTYellowBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_HeimerTYellow_HeimerTYellowBasicAttack2_OnCast` |
| `attack_launch_by_segment[1]` | `Play_sfx_HeimerTYellow_HeimerTYellowBasicAttack_OnMissileLaunch` |
| `attack_launch_by_segment[2]` | `Play_sfx_HeimerTYellow_HeimerTYellowBasicAttack2_OnMissileLaunch` |
| `attack_hit_by_segment[1]` | `Play_sfx_HeimerTYellow_HeimerTYellowBasicAttack_OnHit` |
| `attack_hit_by_segment[2]` | `Play_sfx_HeimerTYellow_HeimerTYellowBasicAttack2_OnHit` |
| `deploy:start` | `Play_sfx_HeimerTYellow_HeimerdingerQSpawnDestroyAudio_OnBuffActivate` |
| `death` | `Play_sfx_HeimerTYellow_HeimerdingerQSpawnDestroyAudio_OnBuffDeactivate` |
| `active:cast` | `Play_sfx_HeimerTYellow_HeimerdingerQSpawnDestroyAudio_OnBuffActivate` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。
