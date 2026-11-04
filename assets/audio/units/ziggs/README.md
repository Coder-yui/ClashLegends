# ziggs 音频映射

普攻两段出手与发射使用对应事件；Q在强化出手和实际落地触发。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Ziggs_ZiggsBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_Ziggs_ZiggsBasicAttack2_OnCast` |
| `bomb:basic_impact` | `Play_sfx_Ziggs_ZiggsBasicAttack_OnHit` |
| `attack_launch_by_segment[1]` | `Play_sfx_Ziggs_ZiggsBasicAttack_OnMissileLaunch` |
| `attack_launch_by_segment[2]` | `Play_sfx_Ziggs_ZiggsBasicAttack2_OnMissileLaunch` |
| `bomb:impact` | `Play_sfx_Ziggs_ZiggsQ_hit` |
| `empowered_swing` | `Play_sfx_Ziggs_ZiggsQ_OnCast` |
| `death` | `Play_vo_Ziggs_Death3D` |
| `death:sfx` | `Play_sfx_Ziggs_Death3D_cast` |
| `empowered_launch` | `Play_sfx_Ziggs_ZiggsQSpell_OnMissileLaunch` |
| `empowered_ready` | `Play_sfx_Ziggs_ZiggsShortFuse_OnBuffActivate` |
| `bomb:second_launch` | `Play_sfx_Ziggs_ZiggsQSpell2_OnMissileLaunch` |
| `bomb:third_launch` | `Play_sfx_Ziggs_ZiggsQSpell3_OnMissileLaunch` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。

按项目设计每次落地都爆炸：仅一次地面爆炸音，停用原版Q接地声，不按伤害目标数重复；3.08秒禁用部署语音已移出正式资源。
