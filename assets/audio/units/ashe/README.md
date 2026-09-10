# 艾希原皮音频

当前普通攻击与万箭齐发使用 14 份 SFX WAV，另接入中文包的 3 份死亡 VO WAV，共 17 份；不改变射速、伤害或技能时间线。

| 项目 cue | 原始事件（省略 Play_sfx_Ashe_） | WAV 数 | 触发 |
| --- | --- | --- | --- |
| attack_swing 两段共享池 | AsheBasicAttack_OnCast | 2 | Attack1/Attack2 开始拉弓 |
| attack_launch | AsheBasicAttack_OnMissileLaunch | 3 | 权威弹体实际生成（通常攻击开始后 0.45 秒） |
| attack_hit | AsheBasicAttack_OnHit | 3 | 箭实际抵达并成功命中 |
| active:start | Volley_OnCast | 2 | Spell2 / active 起手 |
| active:release | VolleyAttackWithSound_OnMissileLaunch | 1 | 权威 0.62 秒 Impact，空放也触发 |
| active:hit | VolleyAttack_OnHit | 3 | 扇区真实成功命中，同次释放多目标只播一次 |
| death（Voice 总线） | Play_vo_Ashe_Death3D（完整事件名） | 3 | 视觉死亡信号，随机一次，角色销毁后允许死亡短音自然结束 |

BasicAttack 与 BasicAttack2 的三类事件分别指向相同的媒体集合；只保存一份声音池供两段使用。保留事件增益，CardDB 额外增益均为 0 dB。导出文件名 snake_case 保留随机编号与 wwiser 重复事件标记 d。

## 未接入与限制

- 部署/待机/移动有意静音；原皮 SFX 事件表无独立死亡事件，已从 VO 事件表精确提取 Death3D，不混入普通对白或其他技能。
- Q、鹰击长空、魔法水晶箭、暴击及旧 FrostArrow 事件不属于当前玩法，不接入。
- 技能结束没有对应选定的短音，不虚构结束声。VolleyAttackWithSound 的离线预览按单次播放保留约 1.67 秒自然尾音，不启动持有式循环或重建完整 Wwise Stop/滤波逻辑。
- 本项目万箭齐发是延迟后的权威扇区结算，不是 8 枚独立权威弹体；释放音与真实命中音因此在同一 Impact 时点触发，不能为了声画效果改伤害时间。
- 声音事件从主机到客户端使用已有 authority-only 不可靠 RPC；允许丢音，不影响权威伤害。普通起手与技能起手读取动作序号，重复帧不重播。

## 来源与重现

- 原包（只读）：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/Ashe.wad.client`。
- 提取路径：`assets/sounds/wwise2016/sfx/characters/ashe/skins/base/ashe_base_sfx_audio.bnk`、`ashe_base_sfx_events.bnk`，以及 `data/characters/ashe/skins/skin0.bin`。
- 共用 init.bnk 使用先前从同一来源 Bootstrap.windows.wad.client 提取的文件；本次没有重新安装工具。
- 工作目录：`/Users/czh/Tools/lol-asset-tools/verification/ashe/`；完整离线解析库：`/Users/czh/Tools/lol-asset-tools/ashe_base_audio/`。
- wadtools 0.5.7、ritobin-tools 0.1.0、bnkextr、wwiser v20260909、vgmstream r2117；处理脚本为外部 `process_ashe_audio.py`。wwiser 使用 `-gra -gd -gv 0dB` 保留分支，vgmstream 使用 `-i` 单次导出；TXTP 的媒体路径改为相对 banks。
- 41 个 SFX 事件名经 ShortID 校验（33 播放、8 停止）；44 个原始媒体全部解析，可达媒体无缺失/未归类，生成 60 份事件预览。4 个未使用事件引用本银行缺失节点，无法生成预览：AsheCritChanceReady_OnBuffActivate → 125783175，FrostArrow OnCast → 9057、OnHit → 9055、OnMissileLaunch → 9056。不能将它们当作已完整解析的静音事件；本次所选 6 个事件均无缺失节点或媒体。
- 项目选择脚本：`python3 tools/import_ashe_audio.py`，只复制白名单 14 WAV 并生成 `event_manifest.json`，原始包和完整解析库不变。该脚本有固定本机路径，重跑会覆盖同名选定产物。

manifest 的 media_ids 是整个事件候选媒体集合，不代表每个变体含全部媒体。恢复的是事件名而不是 Riot 音频工程里的原 WAV 名。离线渲染不等同完整 Wwise 动态参数/随机音高/空间滤波。素材仅供学习原型，其他用途须核实相应权限。

## 验证入口

死亡来源：Ashe.zh_CN.wad.client 内原皮 `ashe_base_vo_events.bnk` 与 `ashe_base_vo_audio.wpk`。包内路径仍标作 vo/en_us，来源语言以 WAD 包为准，不按内部路径误认成英文包。Death3D ShortID 为 1632532837，可达 WEM 为 2639712284、2320440732、2413345029；小型 Audio BNK 不含实际语音，WPK 才是媒体来源。提取器按 r3d2/v1 索引校验范围及 RIFF 文件头，只取三个已验证媒体。

重现脚本 `tools/import_ashe_death_audio.py`；外部源/事件 XML 在 `/Users/czh/Tools/lol-asset-tools/verification/ashe_vo_zh/`，TXTP 与 WAV 在 `/Users/czh/Tools/lol-asset-tools/ashe_death_zh_audio/`。映射独立存于 `death_event_manifest.json`，原来的 event_manifest.json 保留 14 份 SFX；两者合计覆盖 17 个文件。Voice 增益额外为 0 dB，保留原事件层级增益。

空转审判与寒冰死亡联合演示：`Godot --path . --script tools/demos/sustained_audio_demo.gd`；实际混音录音输出至 `/tmp/clash_sustained_audio.wav`。

完整回归：`Godot --headless --path . --script tests/mechanics_check.gd`。
顺序演示普通攻击与万箭齐发：`Godot --path . --script tools/demos/ashe_audio_demo.gd`。
同一脚本在两进程加 `-- --mode=host --auto-test` / `-- --mode=join --auto-test` 可验证两端事件日志。实际听感须结合运行试听，cue 日志不能替代响度与音色判断。
