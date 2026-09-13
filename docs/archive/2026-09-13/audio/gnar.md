> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# gnar 音频映射

小纳尔双段普攻；变小播放 TransformBack。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Gnar_GnarBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_Gnar_GnarBasicAttack2_OnCast` |
| `attack_hit` | `Play_sfx_Gnar_GnarBasicAttack_OnHit` |
| `attack_launch` | `Play_sfx_Gnar_GnarBasicAttack_OnMissileLaunch` |
| `revert:sustain` | `Play_sfx_Gnar_GnarTransformBack_buffactivate` |
| `death` | `Play_vo_Gnar_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## 2026-09-13 普攻发射核对

现有普攻发射 WAV 与原始 BasicAttack 事件重新导出逐字节一致，与技能媒体不同，本次保留。

核对证据：[普攻发射音核对](../research/projectile_launch_audio_audit.md)。

## 2026-09-13 全面复核更新

当前完整覆盖与本次补项以[逐英雄音频复核](../research/hero_audio_completeness_audit.md)及本目录 manifest 为准；前文历史“未接入”说明已由本次结果替代。新增事件保留原音频层与增益，实战由真实状态/效果触发。

## 普攻 launch 生命周期修正（2026-09-13）

根据实战反馈，小纳尔启用 `audio.attack_launch_until_impact = true`：每枚普通弹体生成时播放原 launch 池，命中/免疫碰撞、目标死亡/消失或清场导致弹体结束时立即停止对应播放器。多个在途弹体独立持有，来源变形/死亡不会误停其他弹体。原三份 WAV、0 dB 配置及命中池不变；无需裁剪素材，也不修改伤害或弹体速度。单文件素材试听仍能播放完整源文件，实战声音长度取决于该枚弹体存活时间。

真实渲染探针 `tools/demos/gnar_launch_audio_preview.gd` 中，连续六次攻击的 launch 每次约 0.25–0.30 秒后随命中停止，最终持有播放器数为 0；原 2.26–2.42 秒尾音不再跨多次普攻叠放。实战混音 `/tmp/clash-gnar-launch/local_mix.wav` 可用于复听；播放生命周期已验证，主观音色仍以用户试玩为准。
