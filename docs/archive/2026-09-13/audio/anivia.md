> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# anivia 音频映射

Attack1/2 共用基础出手；GlacialStorm 原事件含 10.469s 风暴，裁取前 0.72s 为施法起音，尾部淡出。落地后接原事件 0.72–3.72 秒段作为区域持续声，结束接 OnBuffDeactivate（约 2.08 秒）。复生/蛋转生仍缺入口。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Anivia_AniviaBasicAttack_OnCast` |
| `attack_swing[2]` | `Play_sfx_Anivia_AniviaBasicAttack_OnCast` |
| `attack_hit` | `Play_sfx_Anivia_AniviaBasicAttack_OnHit` |
| `attack_launch` | `Play_sfx_Anivia_AniviaBasicAttack_OnMissileLaunch` |
| `frost_storm:start` | `Play_sfx_Anivia_GlacialStorm_buffactivate` |
| `frost_storm:zone_sustain` | `Play_sfx_Anivia_GlacialStorm_buffactivate` 的持续段 |
| `frost_storm:zone_end` | `Play_sfx_Anivia_GlacialStorm_OnBuffDeactivate` |
| `death` | `Play_vo_Anivia_Death3D` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

## 2026-09-12 固定区域音频

持续片段为源事件预览 0.72–3.72 秒，25ms 淡入、80ms 淡出；结束事件经 vgmstream-cli -i 解码，保留 TXTP 原 -20dB 增益。max 为另一短事件，本次未把它冒充循环音导入。素材/参数/事件 ID 和哈希已补入 manifest。

区域生成时发送带递增 ID 的可靠纯表现通知；持续声固定在落点，与区域表现共用计时，3 秒结束后播一次消散声。施法者死亡、销毁或受控不终止区域声；工作台暂停也暂停生命周期，清场停止且不补结束声。最多 24 个区域持续播放器，超限回收最旧项。支持较长区域续播，但不宣称样本级无缝循环。

核心回归已覆盖真实区域创建、重复通知、施法者销毁、到期及清场；host/join 双端各收到一次持续与结束事件。实际运行录音见 `/tmp/clash-card-playtest-fixes/anivia_live_mix.wav`，已触发并录制主混音；最终主观音量/听感仍待用户试听。普攻本轮未修改。

## 2026-09-13 普攻发射核对

现有普攻发射 WAV 与原始 BasicAttack 事件重新导出逐字节一致，与技能媒体不同，本次保留。

核对证据：[普攻发射音核对](../research/projectile_launch_audio_audit.md)。

## 2026-09-13 全面复核更新

当前完整覆盖与本次补项以[逐英雄音频复核](../research/hero_audio_completeness_audit.md)及本目录 manifest 为准；前文历史“未接入”说明已由本次结果替代。新增事件保留原音频层与增益，实战由真实状态/效果触发。

2026-09-13 按原始挥翼节点再次校准：1.133333 秒动画映射到 1.7 秒攻击周期，swing 0.60 秒、弹体创建及 launch 0.675 秒，lead 0.075 秒；音频文件不变，替代此前较长提前量。

### 3 秒孵化适配修复（2026-09-13）

移除凤凰 replacement:start 的 6.7977 秒一次性声音。原 Rebirth_OnBuffActivate 的前 6 秒使用 ffmpeg atempo=2 保音高压缩至 3 秒，作为蛋持有的 revival:sustain，一次播放不循环；死亡、销毁和清场立即停止，控制效果不暂停（权威孵化计时也不暂停）。原音尾部 6 秒后约 0.8 秒作为 revival:end，仅成功孵化触发；不再使用原先的 Rebirth_cast 映射。原素材保留，派生产物及处理参数见 manifest。

凤凰模型在 0.0099 基础上再放大 15% 至 0.011385，权威碰撞半径设为 20 像素（0.5 格）；表现半径同步增大 15%，血条顶部投影和高度上限随之调整。蛋体型不变。

### 完整原音减半与击破表现（2026-09-13）

按用户最新要求，完整 6.797687 秒 Rebirth_OnBuffActivate 先统一 atempo=2 保音高压缩，再在输出第 3 秒处分为孵化过程和约 0.4 秒成功破壳尾音；不再保留原速 0.8 秒尾音，分割处不另加淡入淡出。蛋被击破立即停止过程音。原事件库只有 Death3D_cast、Rebirth_OnBuffActivate、Rebirth_cast 等，没有可明确归属于独立蛋碎的事件；采用凤凰模型 Death（2.4 秒，与当前凤凰一致）及凤凰现有三条死亡 VO 随机池，跳过蛋死亡动画。成功复生仍只播放破壳尾音，不播放死亡动作或死亡 VO。

### 连续音轨与事件去重修订（2026-09-13）

原始复生音整体减半后连续播放完整 3.406916 秒，不再拆段；变蛋时启动，击杀/销毁停止。成功复生将同一播放器转为尾音持有，保持播放位置与音频流，播完自然释放；主机与客户端沿用已有可靠复生/移除通知，不重新触发 revival:end 音频。
