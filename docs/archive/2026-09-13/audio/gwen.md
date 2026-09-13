> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# gwen 音频映射

原始动画图 SoundEventData 确认 Attack1=Swipe、Attack2=Stab、Attack3=Swipe，出手与命中分别映射。Q 四档按真实剪切时间合成可中断出手音轨；丝缕缠流已取消被动身份，本轮明确不接其音频。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Gwen_GwenBasicAttack_Swipe_cast` |
| `attack_swing[2]` | `Play_sfx_Gwen_GwenBasicAttack_Stab_cast` |
| `attack_swing[3]` | `Play_sfx_Gwen_GwenBasicAttack_Swipe_cast` |
| `attack_hit` | `Play_sfx_Gwen_GwenBasicAttack_Swipe_hit` |
| `attack_hit_by_segment[1]` | `Play_sfx_Gwen_GwenBasicAttack_Swipe_hit` |
| `attack_hit_by_segment[2]` | `Play_sfx_Gwen_GwenBasicAttack_Stab_hit` |
| `attack_hit_by_segment[3]` | `Play_sfx_Gwen_GwenBasicAttack_Swipe_hit` |
| `death` | `Play_vo_Gwen_Death3D` |
| `active_0:sustain` | `0.095s Play_sfx_Gwen_GwenQFirst_cast → 1.044s Play_sfx_Gwen_GwenQLast_cast` |
| `active_1:sustain` | `0.095s Play_sfx_Gwen_GwenQFirst_cast → 0.949s Play_sfx_Gwen_GwenQMiddle_1stack_cast → 1.044s Play_sfx_Gwen_GwenQLast_cast` |
| `active_2:sustain` | `0.095s Play_sfx_Gwen_GwenQFirst_cast → 0.783s Play_sfx_Gwen_GwenQMiddle_1stack_cast → 0.949s Play_sfx_Gwen_GwenQMiddle_1stack_cast → 1.044s Play_sfx_Gwen_GwenQLast_cast` |
| `active_3:sustain` | `0.095s Play_sfx_Gwen_GwenQFirst_cast → 0.616s Play_sfx_Gwen_GwenQMiddle_1stack_cast → 0.783s Play_sfx_Gwen_GwenQMiddle_1stack_cast → 0.949s Play_sfx_Gwen_GwenQMiddle_1stack_cast → 1.044s Play_sfx_Gwen_GwenQLast_cast` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## Q 实际命中音（2026-09-13）

- `active_N:hit_first` → `Play_sfx_Gwen_GwenQFirst_hit`
- `active_N:hit_middle` → `Play_sfx_Gwen_GwenQMiddle_hit`（层数 1–3）
- `active_N:hit_last` → `Play_sfx_Gwen_GwenQLast_hit`

各 3 个原始随机变体，保留事件增益。成功剪中才播，每剪多目标去重，空剪静音；1.5 秒施法和出手合成音轨不变。center/minion 条件音色已发现，暂未分流，当前统一采用基本命中音。详见 event_manifest.json 与 [核对记录](../research/q_audio_animation_audit.md)。

## 2026-09-13 全面复核更新

当前完整覆盖与本次补项以[逐英雄音频复核](../research/hero_audio_completeness_audit.md)及本目录 manifest 为准；前文历史“未接入”说明已由本次结果替代。新增事件保留原音频层与增益，实战由真实状态/效果触发。

## 2026-09-13 被动改版

`shroud:start/sustain/end` 已从卡牌 audio 域与 tools/audio/card_audio_plan.json 移除，W 素材与来源 manifest 仅保留归档，当前不播放。未来丝缕缠流可选主动尚未实现。新百分比附加伤害与基础命中一起结算，使用现有普攻/剪切命中声音，不重复叠播一次命中。真实混音录制于 `/tmp/clash-gwen-passive/live_mix.wav`，主观听感尚待用户验收。
