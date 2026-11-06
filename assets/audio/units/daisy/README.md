# daisy 音频映射

小菊两段普通攻击和第三段猛击分别选择原始事件，出生独立播放。死亡声音等待核查源映射。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Ivern_IvernR_Daisy_attack_into` |
| `attack_swing[2]` | `Play_sfx_Ivern_IvernR_Daisy_attack_into` |
| `attack_swing[3]` | `Play_sfx_Ivern_IvernR_Daisy_slam_into` |
| `attack_hit_by_segment[1]` | `Play_sfx_Ivern_IvernR_Daisy_hit` |
| `attack_hit_by_segment[2]` | `Play_sfx_Ivern_IvernR_Daisy_hit` |
| `attack_hit_by_segment[3]` | `Play_sfx_Ivern_IvernR_Daisy_slam_hit` |
| `deploy:start` | `Play_sfx_Ivern_IvernR_DaisySpawn_cast` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

死亡由原生Death_Sound粒子绑定Play_sfx_SRU_Blue_death_cast，来自Map11/npc_map11_blue_sfx，使用通用死亡包络。
