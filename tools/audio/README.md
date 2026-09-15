# 音频加工工具

返回 [工具索引](../README.md)。完整规则见 [音频接入](../../docs/AUDIO_INTEGRATION.md)。

| 可复用入口 | 用途 |
| --- | --- |
| `find_lol_voice.py --help` | 用中文台词查原始事件，再从本地银行解码与本地转写定位候选 |
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

## 按台词定位本地英雄语音

`find_lol_voice.py` 只读取网站公开台词 JSON，不下载网站音频。正式声音仍从只读本地 WAD 提取，先用已有 `prepare_lol_card_audio.py` 准备 banks/WEM。所有输出必须位于开发素材库，新目录/JSON 不覆盖已有结果。

```sh
python3 tools/audio/find_lol_voice.py catalog --champion-id 266 --output 'ClashLegends-开发素材库/03-制作中/剑魔/voice-selection/catalog-new.json'
python3 tools/audio/find_lol_voice.py search --index 'ClashLegends-开发素材库/03-制作中/剑魔/voice-selection/catalog.json' --text '我回来了'
python3 tools/audio/find_lol_voice.py render-event --source /absolute/path/to/prepared-voice --init /absolute/path/to/init.bnk --event Play_vo_Aatrox_UseItem3DGuardianAngelR --output 'ClashLegends-开发素材库/04-中间产物/voice-event-new' --wwiser /absolute/path/to/wwiser --vgmstream /absolute/path/to/vgmstream-cli
```

`search` 返回原始事件与网站台词键；**网站键不是当前本地 WEM 媒体编号**，版本不同不能直接换算。`render-event` 保留事件随机分支，输出浮点 WAV、TXTP 和来源哈希。正式入库前另行选择变体、检查峰值和加工增益。

Apple Silicon 可在素材库中间产物的独立 Python 环境安装 `mlx-whisper`（代理需要时安装 `httpx[socks]`），运行：

```sh
/path/to/venv/bin/python tools/audio/find_lol_voice.py transcribe --directory /absolute/path/to/wav --glob '*.wav' --output 'ClashLegends-开发素材库/04-中间产物/voice-transcripts-new.json'
python3 tools/audio/find_lol_voice.py search --index 'ClashLegends-开发素材库/04-中间产物/voice-transcripts-new.json' --text '回來'
```

首次转写下载公开 MLX Whisper Small 模型权重；音频始终在本机处理。`--model` 可替换模型。转写可能使用繁体或识错，宜用短句片段搜索，再核对原始事件并试听，不能直接把 ASR 当人工确认；输出默认 `verified_by_listening: false`。客户端英雄选择/禁用台词需从本地 LCU 语言 WAD 的 `champion-choose-vo` / `champion-ban-vo/<英雄ID>.ogg` 提取，不一定在游戏角色音频银行里。
