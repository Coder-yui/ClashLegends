# pantheon 音频映射

基础皮肤短Q与R落地；不使用蓄力、投矛或起跳声音。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Pantheon_PantheonBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_Pantheon_PantheonBasicAttack2_OnCast` |
| `attack_swing[3]` | `Play_sfx_Pantheon_PantheonBasicAttack3_OnCast` |
| `attack_hit` | `Play_sfx_Pantheon_PantheonBasicAttack_OnHit` |
| `attack_hit_by_segment[1]` | `Play_sfx_Pantheon_PantheonBasicAttack_OnHit` |
| `attack_hit_by_segment[2]` | `Play_sfx_Pantheon_PantheonBasicAttack2_OnHit` |
| `attack_hit_by_segment[3]` | `Play_sfx_Pantheon_PantheonBasicAttack3_OnHit` |
| `pre_deploy:start` | RMissile3_OnMissileLaunch + R_land_vfx + RMissile_OnMissileLaunch + R_buffactivate_vfx + R_impact_vfx + R_shockwave_vfx（后方着地及滑行混音） |
| `deploy:start` | 不配置；拿起长矛时不重复爆炸音 |
| `spear_tap:start` | `Play_sfx_Pantheon_PantheonQTap_cast_lua` |
| `spear_tap:hit` | `Play_sfx_Pantheon_PantheonQTap_hit_vfx` |
| `spear_tap_empowered:start` | `Play_sfx_Pantheon_PantheonQTap_cast_empowered_lua` |
| `spear_tap_empowered:hit` | `Play_sfx_Pantheon_PantheonQTap_hit_empowered_vfx` |
| `attack_swing[4] / attack_hit_by_segment[4]` | BasicAttack2对应OnCast / OnHit |
| `resource_full` | `Play_sfx_Pantheon_PantheonPassiveReady_OnBuffActivate` |
| `death` | `Play_sfx_Pantheon_Death3D` |
| `death:voice` | `Play_vo_Pantheon_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli解码原始事件，SFX浮点转PCM16的统一余量见下文，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。

2026-09-26：33个SFX以vgmstream-cli -i -W 4重新解码，统一-2.320351dB后转PCM16，最高峰-1dB、无截顶；3个VO保持原有0.8秒加工。新死亡SFX使用上面的1.5秒包络。总计36个文件。浮点制作产物留在开发素材库04-中间产物/潘森动作音频核对/20260926；运行仅依赖本目录WAV。

当前3格滑行版本：pantheon_r_arrival_original.wav按0/0.2/0.2/0.65/0.65/1.3秒排列RMissile3、R_land、RMissile、R_buffactivate、R_impact、R_shockwave。六个TXTP浮点解码，不变调或变速；组合统一-4.797360dB，总长3.45秒含尾音，末0.12秒淡出。共36个运行WAV；旧单独landing音轨归档。制作脚本在素材库03-制作中/潘森/落地方向与时序/build_audio.py；哈希与原始事件见event_manifest.json。
