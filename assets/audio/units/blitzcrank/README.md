# blitzcrank 音频映射

蒸汽机器人原版基础皮肤，普攻两段、Q起手与命中、E准备与出拳、死亡音效与中文语音；部署使用中文客户端原版选人语音，运行时补偿 -8dB。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Blitzcrank_BlitzcrankBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_Blitzcrank_BlitzcrankBasicAttack2_OnCast` |
| `attack_hit_by_segment[1]` | `Play_sfx_Blitzcrank_BlitzcrankBasicAttack_OnHit` |
| `attack_hit_by_segment[2]` | `Play_sfx_Blitzcrank_BlitzcrankBasicAttack2_OnHit` |
| `empowered_hit` | `Play_sfx_Blitzcrank_PowerFist_hit` |
| `pull:start` | `Play_sfx_Blitzcrank_RocketGrab_OnCast` |
| `pull:hit` | `Play_sfx_Blitzcrank_RocketGrabMissile_OnHit` |
| `empowered_buff:start` | `Play_sfx_Blitzcrank_PowerFist_OnBuffActivate` |
| `empowered_swing` | `Play_sfx_Blitzcrank_PowerFist_OnCast` |
| `death` | `Play_sfx_Blitzcrank_Death3D_cast` |
| `death:voice` | `Play_vo_Blitzcrank_Death3D` |
| `deploy` | 中文客户端 `champion-choose-vo/53.ogg` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。
