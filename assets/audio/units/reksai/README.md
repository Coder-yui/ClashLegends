# reksai 音频映射

普通攻击两段与女王之怒、出土分开映射；无地上行走音。死亡SFX另行执行1.5秒包络。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Reksai_ReksaiBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_Reksai_ReksaiBasicAttack2_OnCast` |
| `attack_hit` | `Play_sfx_Reksai_ReksaiBasicAttack_OnHit` |
| `empowered_hit_by_segment` | `ReksaiQAttack / QAttack2 / QAttack3 OnHit` |
| `empowered_swing_by_segment` | `ReksaiQAttack / QAttack2 / QAttack3 OnCast` |
| `active:cast` | `Play_sfx_Reksai_ReksaiQ_OnCast` |
| `empowered_buff:start / end` | `ReksaiQ_OnBuffActivate / OnBuffDeactivate` |
| `pre_deploy:sustain` | `Play_sfx_Reksai_RekSaiW_movement_trail` |
| `deploy:hit` | `Play_sfx_Reksai_RekSaiW_hit` |
| `deploy:start` | `Play_sfx_Reksai_RekSaiW_buffdeactivate` |
| `death:voice` | `Play_vo_Reksai_Death3D` |
| `death` | `Play_sfx_Reksai_Death3D_cast` |
| `deploy:voice` | `Play_vo_Reksai_Move2DStandard` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态见[本卡音频手册](../../../../docs/units/audio/reksai.md)。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。

Q三击按 QAttack / QAttack2 / QAttack3 事件分别取池。共47项变体身份、35个独立文件；三段命中PCM相同，equivalent_sources保留原事件路径。

预部署潜行持续声按用户反馈增加12dB运行播放增益；原始WAV及来源哈希不变，正式目录只保留已引用音轨。
