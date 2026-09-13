> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# twisted_fate 音频映射

Attack1/2/3/4 → Spell3，第五击使用 E CardmasterStack，出手与命中均分段。万能牌使用 WildCards_OnCast，未找到独立命中素材。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_TwistedFate_TwistedFateBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_TwistedFate_TwistedFateBasicAttack2_OnCast` |
| `attack_swing[3]` | `Play_sfx_TwistedFate_TwistedFateBasicAttack3_OnCast` |
| `attack_swing[4]` | `Play_sfx_TwistedFate_TwistedFateBasicAttack4_OnCast` |
| `attack_swing[5]` | `Play_sfx_TwistedFate_CardmasterStack_cast` |
| `attack_hit` | `Play_sfx_TwistedFate_TwistedFateBasicAttack_OnHit` |
| `attack_hit_by_segment[1]` | `Play_sfx_TwistedFate_TwistedFateBasicAttack_OnHit` |
| `attack_hit_by_segment[2]` | `Play_sfx_TwistedFate_TwistedFateBasicAttack2_OnHit` |
| `attack_hit_by_segment[3]` | `Play_sfx_TwistedFate_TwistedFateBasicAttack3_OnHit` |
| `attack_hit_by_segment[4]` | `Play_sfx_TwistedFate_TwistedFateBasicAttack4_OnHit` |
| `attack_hit_by_segment[5]` | `Play_sfx_TwistedFate_CardmasterStack_hit` |
| `wild_cards:sustain` | `Play_sfx_TwistedFate_WildCards_OnCast` |
| `pre_deploy:start` | `Play_sfx_TwistedFate_Gate_marker`，三个完整变体保持音高压缩至 1.75 秒 |
| `death` | `Play_vo_TwistedFate_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

Gate_marker 使用三个完整原始事件 WAV，原长约 3.75–3.85 秒；两段 ffmpeg atempo 保持音高压缩，输出校准到 1.75 秒，不再选择尾部片段，保留源 -15 dB 事件增益。预部署开始播放一次，1.75 秒结束直接生成可参战单位，deploy_time=0，无第二次声音和部署读条。处理详情与源哈希见 manifest；通用导入后运行 tools/audio/import_twisted_fate_deploy_audio.py。原 last_1s 文件保留为历史来源，不再配置使用。

2026-09-13 被动修正：第五击改为单弹体携带 1.5 倍伤害；继续使用已导入的 E `CardmasterStack_cast` 两变体和 `CardmasterStack_hit` 三变体，出手一次、真实命中一次。删除卡牌的延迟追加攻击配置，不再生成第二弹体或第二次命中声。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## 2026-09-13 普攻发射核对

新增 `attack_launch_by_segment`：前四段共用 BasicAttack_OnMissileLaunch 四个变体，第五段使用 CardmasterStack_missilelaunch 三个变体。保留原始事件增益，详见 event_manifest.json。

核对证据：[普攻发射音核对](../research/projectile_launch_audio_audit.md)。

## Q 发射声（2026-09-13）

`wild_cards:release` → `Play_sfx_TwistedFate_SealFateMissile_OnMissileLaunch`，4 个随机变体。原 spell 数据中 Q_Mis/Q_Tar 确认归属，在现有 0.25 秒 release 播放一次；保留原始增益/尾音。详见[核对记录](../research/q_audio_animation_audit.md)。

`wild_cards:hit` → `Play_sfx_TwistedFate_SealFateMissile_OnHit`（原双层组合，约 1.15 秒），只在成功伤害时播放一次，空放静音。现已改为权威穿透弹体：0.25 秒释放，实际碰撞时才伤害/播放 hit；每个目标每次施法最多一次。

最终试听选择：Gate_marker 原声前 1.75 秒（first_1_75s），不再使用 full_1_75s 压缩版本。部署分为 1.3 秒预部署 + 0.45 秒实际部署。
