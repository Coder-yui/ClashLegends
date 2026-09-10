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
python3 tools/import_masteryi_audio.py
```

该脚本只从项目外已经解析好的白名单事件复制 WAV 并重建 `event_manifest.json`，不会修改原始 WAD 或外部解析库。
