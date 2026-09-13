> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# xin 音频映射

Attack1_Hit / Attack3_Hit / Passive_AA；第三段为被动攻击，出手与命中分别映射。部署 R 与主动同动作，但部署缺 cue；回血和 nova 命中缺入口。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_XinZhao_XinZhaoBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_XinZhao_XinZhaoBasicAttack2_OnCast` |
| `attack_swing[3]` | `Play_sfx_XinZhao_XinZhaoPassiveCritAttack_OnCast` |
| `attack_hit` | `Play_sfx_XinZhao_XinZhaoBasicAttack_OnHit` |
| `attack_hit_by_segment[1]` | `Play_sfx_XinZhao_XinZhaoBasicAttack_OnHit` |
| `attack_hit_by_segment[2]` | `Play_sfx_XinZhao_XinZhaoBasicAttack2_OnHit` |
| `attack_hit_by_segment[3]` | `Play_sfx_XinZhao_XinZhaoPassiveCritAttack_OnHit` |
| `active:start`（起始 0.65 秒） | `Play_sfx_XinZhao_XinZhaoR_OnCast` |
| `death` | `Play_vo_XinZhao_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## 2026-09-13 全面复核更新

当前完整覆盖与本次补项以[逐英雄音频复核](../research/hero_audio_completeness_audit.md)及本目录 manifest 为准；前文历史“未接入”说明已由本次结果替代。新增事件保留原音频层与增益，实战由真实状态/效果触发。

## 当前横扫接入（2026-09-13）

部署与主动使用 OnCast 起始 0.65 秒（0.55–0.65 秒线性淡出），不播放后续长尾；新增 deploy:voice / active:voice，随机播放四个原始中文 R cast3D 喊声之一，Voice 总线。未接原版 R 后续持续护卫音。源事件 ID、媒体与处理哈希见 manifest；通用批量导入后运行 tools/audio/import_xin_sweep_audio.py 恢复此选择。

已通过事件去重、资源时长与核心回归，并运行工作台播放录音；最终主观听感仍需用户试听确认。

新月护卫命中池：`Play_sfx_XinZhao_XinZhaoR_hitlocation_knockback` 两个变体，约 3.148 / 3.207 秒，部署和主动共享；真实伤害成功时每次横扫只派发一次，不按命中人数叠播。此命中池独立于已截短的施放声，本次特效重制保留命中素材。
