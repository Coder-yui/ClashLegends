# azir 音频映射

沙漠皇帝基础皮肤：两段普攻出手、对应命中与死亡；W由实际生成的士兵出生音播放。原事件增益，未做归一化。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Azir_AzirBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_Azir_AzirBasicAttack2_OnCast` |
| `attack_hit_by_segment[1]` | `Play_sfx_Azir_AzirBasicAttack_OnHit` |
| `attack_hit_by_segment[2]` | `Play_sfx_Azir_AzirBasicAttack2_OnHit` |
| `death` | `Play_sfx_Azir_Base_Death3D_cast` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 [本次记录](../../../../docs/deliveries/2026-10-09_沙漠皇帝新卡.md)。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。
