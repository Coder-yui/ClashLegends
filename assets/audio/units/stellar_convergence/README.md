# stellar_convergence 音频映射

原版E施放、区域持续/结束；hit_start用于每目标首次实际受击；Execute_Player粒子明确绑定EDebuff_buffdeactivate，改造为本卡成功斩杀音效。StackProc的hit_wave不作普通命中替代。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `spell:cast` | `Play_sfx_AurelionSol_AurelionSolE_OnCast` |
| `spell:zone_sustain` | `Play_sfx_AurelionSol_AurelionSolE_buffactivate_aoe_other` |
| `spell:zone_end` | `Play_sfx_AurelionSol_AurelionSolE_buffdeactivate` |
| `spell:hit` | `Play_sfx_AurelionSol_AurelionSolE_hit_start` |
| `spell:execute` | `Play_sfx_AurelionSol_AurelionSolEDebuff_buffdeactivate` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。
