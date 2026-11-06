# sona 音频映射

Sona基础皮肤普攻/W/R事件；来源未列出死亡SFX或Death3D VO，明确保留缺项。部署使用客户端英雄选择语音。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `deploy:voice` | 中文客户端 `champion-choose-vo/37.ogg`，运行补偿−12.5dB |
| `attack_swing[1]` | `Play_sfx_Sona_SonaBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_Sona_SonaBasicAttack_OnCast` |
| `attack_swing[3]` | `Play_sfx_Sona_SonaBasicAttack_OnCast` |
| `attack_hit` | `Play_sfx_Sona_SonaBasicAttack_OnHit` |
| `attack_launch` | `Play_sfx_Sona_SonaBasicAttack_OnMissileLaunch` |
| `heal_aura:start` | `Play_sfx_Sona_SonaW_OnCast` |
| `heal_aura:sustain` | `Play_sfx_Sona_SonaAmbientWSound_OnBuffActivate` |
| `crescendo:sustain` | `Play_sfx_Sona_SonaR_OnCast` |
| `crescendo:release` | `Play_sfx_Sona_SonaR_OnMissileLaunch` |
| `crescendo:hit` | `Play_sfx_Sona_SonaR_OnHit` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见[琴瑟仙女音频页](../../../../docs/units/audio/sona.md)。
