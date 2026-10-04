# tristana 音频映射

> 2026-10-04 原版增益重导：当前文件与加工参数以 `assets/audio/original_gain_manifest.json` 为准；下面历史文字中的额外增益、制作余量及旧哈希说明已被本次重导替代。工具主增益、后期固定增益和事件播放补偿均为 0 dB；原事件内部增益保留。


原版基础皮肤：普攻双动作、真实命中、Q开始/结束、死亡语音。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_hit` | `Play_sfx_Tristana_TristanaBasicAttack_OnHit` |
| `attack_launch` | `Play_sfx_Tristana_TristanaBasicAttack_OnMissileLaunch` |
| `active_buff:start` | `Play_sfx_Tristana_TristanaQ_OnCast` |
| `active_buff:end` | `Play_sfx_Tristana_TristanaQ_OnBuffDeactivate` |
| `death` | `Play_vo_Tristana_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/units/audio/tristana.md。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。

最终音频重新以vgmstream-cli -W 4浮点解码，所有事件统一降低4dB后转PCM16，消除事件增益导致的转换削顶；不逐文件归一化。最终哈希及死亡淡出见event_manifest.json。

部署使用 `deploy:voice` 随机池：交火咯（Attack2DGeneral r18）、预备，瞄准，射（同事件 r17）、碰不到我（TristanaW_cast3DLowHealth r5）。源事件不限制项目映射用途。公开台词目录与本地 ASR 逐句对应；统一 -4 dB 后 PCM16，完整保留台词。本次已实际运行触发与播放，但未作主观听感确认。
