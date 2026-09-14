> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# 赏金猎人原皮音频

当前玩法接入 52 份原皮音频：两段普攻出手、真实弹体离弦、共享普攻命中、被动首次攻击完整链条、LOL W（`ViciousStrikes`）施放/持续/结束，以及中文死亡语音。音频只读取攻击序号、实际弹体事件、权威被动效果、Buff 状态和死亡信号，不参与伤害、移动或技能计时。

| 项目 cue | 原始事件（省略 `Play_sfx_MissFortune_`） | WAV 数 | 触发 |
| --- | --- | ---: | --- |
| `attack_swing[0]` | `MissFortuneBasicAttack_OnCast` | 3 | `Attack1` 出手 |
| `attack_swing[1]` | `MissFortuneBasicAttack2_OnCast` | 3 | `Attack2` 出手 |
| `attack_launch` | `MissFortuneBasicAttack_OnMissileLaunch` | 3 | 权威弹体实际生成 |
| `attack_hit` | `MissFortuneBasicAttack_OnHit` | 24 | 普攻弹体真实命中；`BasicAttack2_OnHit` 与其共享同一套 Switch/随机素材 |
| `first_strike:cast` | `MissFortunePassiveAttack_OnCast` | 2 | 先声夺人攻击起手；替换该次普通挥击音 |
| `first_strike:missile_cast` | `MissFortunePassiveAttack_OnMissileCast` | 2 | 首击弹体准备阶段 |
| `first_strike:missile_launch` | `MissFortunePassiveAttack_OnMissileLaunch` | 2 | 首击弹体实际离弦 |
| `first_strike_hit` | `MissFortunePassiveAttack_OnHit` | 2 | 先声夺人首次真实命中；替换该次 `attack_hit`，不额外叠播 |
| `first_strike:hit_location` | `MissFortunePassiveAttack_OnHitLocation` | 1 | 首击命中位置层，与首击命中事件同时触发 |
| `active_buff:start` | `MissFortuneViciousStrikes_OnCast` | 2 | 大步流星（LOL W）权威 Buff 开始 |
| `active_buff:sustain` | `MissFortuneViciousStrikes_OnBuffActivate` | 2 | 大步流星期间的单位持有音层，随单位移动，Buff 结束或死亡时停止 |
| `active_buff:end` | `MissFortuneViciousStrikes_OnBuffDeactivate` | 2 | 大步流星权威 Buff 结束 |
| `death`（Voice 总线） | `Play_vo_MissFortune_Death3D` | 4 | `Death` 表现信号 |

## 来源与限制

- SFX 原包：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/MissFortune.wad.client` 的原皮基础 SFX Audio/Events BNK。
- 死亡语音原包：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/MissFortune.zh_CN.wad.client`；包内路径仍标作 `vo/en_us`，语言依据源 WAD 包名记录为中文。
- 离线解析工作目录：`/Users/czh/Tools/lol-asset-tools/verification/missfortune/` 与 `missfortune_vo_zh/`；使用 `wadtools`、`ritobin-tools`、`bnkextr`、`wwiser v20260909`、`vgmstream r2117`。`vgmstream` 使用 `-i` 单次导出，保留事件层级增益。
- `event_manifest.json` 记录项目文件到原始事件、ShortID、事件预览和候选媒体集合的映射。`media_ids` 是事件图候选集合，不表示每个变体包含全部 WEM；文件名中的 Switch 数字与 `rN` 变体标记保留可追溯信息。
- `OnBuffActivate` 原片段约 6 秒，作为项目一次性持有音层使用；项目 Buff 当前持续 3 秒，结束时由通用音频生命周期停止，不实现 Wwise 无限循环或淡出。
- 被动接入 `PassiveAttack_OnCast` → `OnMissileCast` → `OnMissileLaunch` → `OnHit` + `OnHitLocation` 完整链条，各阶段先保留两个已验证自然变体（命中位置层为单一事件）；`PassiveAttack2` 与 `PassiveAttackCrit` 未接入，避免把攻击段或暴击语义误播到当前玩法。
- `StrutStacks_OnBuffCast` 是 W 的被动层数事件，不是“先声夺人”首次命中事件，因此未接入；同样没有导入 `BulletTime`、被动弹射、R 大招或其他皮肤事件。
- 原始 WAD、BNK、WPK 和完整解析库均保留在开发素材库内；素材仅供学习原型使用，其他用途需核实相应权限。

## 重现

```sh
python3 tools/audio/import_missfortune_audio.py
```

脚本只从开发素材库内已经解析好的白名单事件复制 WAV 并重建 `event_manifest.json`，不会修改原始 WAD 或外部解析库。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## 2026-09-13 全面复核更新

当前完整覆盖与本次补项以[逐英雄音频复核](../research/hero_audio_completeness_audit.md)及本目录 manifest 为准；前文历史“未接入”说明已由本次结果替代。新增事件保留原音频层与增益，实战由真实状态/效果触发。
