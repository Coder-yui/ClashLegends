> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# 剑圣原皮音频

当前玩法接入 32 份原皮 SFX WAV：三段普攻出手、普通普攻真实命中、高原血统起止/持续层和死亡声。音频只读取权威攻击序号、主动 Buff 状态和死亡信号，不改变伤害或计时。

| 项目 cue | 原始事件（省略 `Play_sfx_MasterYi_`） | WAV 数 | 触发 |
| --- | --- | ---: | --- |
| `attack_swing[0]` | `MasterYiBasicAttack_OnCast` | 5 | 第一段普攻出手 |
| `attack_swing[1]` | `MasterYiBasicAttack2_OnCast` | 4 | 第二段普攻出手 |
| `attack_swing[2]` | `MasterYiDoubleStrike_OnCast` | 3 | 第三段双重打击动作出手 |
| `attack_hit` | `MasterYiBasicAttack_OnHit` | 16 | 任意普通攻击刀次真实命中；追加刀共享普通命中池 |
| `active_buff:start` | `Highlander_OnBuffActivate` | 1 | 高原血统权威 Buff 开始 |
| `active_buff:sustain` | `Highlander_trail` | 1 | 高原血统期间的单位持有音层，随单位移动，结束时停止 |
| `active_buff:end` | `Highlander_OnBuffDeactivate` | 1 | 高原血统权威 Buff 结束 |
| `death` | `Death3D_cast` | 1 | 剑圣死亡表现信号 |

## 来源与限制

- 原包（只读）：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/MasterYi.wad.client`。
- 提取路径：原皮 `assets/sounds/wwise2016/sfx/characters/masteryi/skins/base/masteryi_base_sfx_audio.bnk`、`masteryi_base_sfx_events.bnk` 与 `data/characters/masteryi/skins/skin0.bin`；共用 `init.bnk` 使用已验证的项目外提取副本。
- 工作目录：`/Users/czh/Tools/lol-asset-tools/verification/masteryi/`；完整离线解析库：`/Users/czh/Tools/lol-asset-tools/masteryi_base_audio/`。
- 使用 wadtools、ritobin-tools、bnkextr、wwiser v20260909、vgmstream；wwiser 使用 `-gra -gd -gv 0dB` 保留事件随机分支，vgmstream 使用 `-i` 单次导出。完整事件映射在外部解析库的 `event_map.json`，项目白名单映射在本目录的 `event_manifest.json`。
- `Highlander_trail` 是一次播放的持有式音层，不实现 Wwise 无限循环；技能结束或死亡会停止它。项目当前没有独立的技能表现动作，因此使用通用 `active_buff:*` 入口。
- 普攻命中入口当前按“所有真实普通攻击刀次共享一个 `attack_hit` 池”消费，因此没有把原始 `MasterYiDoubleStrike_OnHit` 混入普通攻击命中池；不会让音频影响双重打击伤害。
- 素材仅供学习原型使用，其他用途须核实相应权限。

## 重现

```sh
python3 tools/audio/import_masteryi_audio.py
```

该脚本只从项目外已经解析好的白名单事件复制 WAV 并重建 `event_manifest.json`，不会修改原始 WAD 或外部解析库。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## 2026-09-13 全面复核更新

当前完整覆盖与本次补项以[逐英雄音频复核](../research/hero_audio_completeness_audit.md)及本目录 manifest 为准；前文历史“未接入”说明已由本次结果替代。新增事件保留原音频层与增益，实战由真实状态/效果触发。

### 连续音轨与事件去重修订（2026-09-13）

双重打击 TXTP 已组合两刀（第二刀延后 0.2 秒），之前两次伤害结算重复播放整组音频。第三段 attack_hit_once_by_segment=true，按单位/形态/攻击序号仅在首次成功命中播放整组；两次伤害仍独立结算。追加刀保存原攻击来源，防止后续攻击或目标变化导致音频段号偏移。
