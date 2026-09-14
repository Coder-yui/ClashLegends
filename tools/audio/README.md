# 音频加工工具

返回 [工具索引](../README.md)。完整规则见 [音频接入](../../docs/AUDIO_INTEGRATION.md)。

| 可复用入口 | 用途 |
| --- | --- |
| `prepare_lol_card_audio.py --help` | 给定 WAD、Init 音频库、英雄和素材库输出目录，准备原始事件素材；需要外部转换工具 |
| `import_card_audio.py --help` | 按明确计划与 `--cards` 选择导入；先 `--dry-run` 核对目标 |
| `audio_manifest_merge.py` | 多个导入器共用的来源清单合并 |
| `death_audio_envelope.py` | 普通单位死亡声时长和淡出加工 |

统一调用：`python3 tools/dev.py audio-prepare --help`、`python3 tools/dev.py audio-import --help`。临时试听用 `python3 tools/dev.py audio --directory /声音目录`。

## 已有专用配方

以下脚本保留原路径，便于素材记录追溯；它们含固定事件选择、裁剪或增益，有些直接运行即写入，**不要批量重放**。新增卡牌先选通用入口和独立计划；旧 `card_audio_plan.json` 不是当前所有修订的完整重建配方。

- `import_apex_spawn_audio.py`：高级炮台部署。
- `import_ashe_audio.py`：艾希。
- `import_ashe_death_audio.py`：艾希死亡声。
- `import_event_audio_expansion.py`：一批补充事件。
- `import_garen_audio.py`：盖伦。
- `import_masteryi_audio.py`：易大师。
- `import_match_audio.py`：比赛全局声音。
- `import_missfortune_audio.py`：厄运小姐。
- `import_sun_disc_tombstone_audio.py`：太阳圆盘与墓碑。
- `import_twisted_fate_deploy_audio.py`：崔斯特部署。
- `import_xin_sweep_audio.py`：赵信横扫。

运行前核对脚本内源库与目标、对应单位的素材 README 和 manifest；只重放需要的配方。
