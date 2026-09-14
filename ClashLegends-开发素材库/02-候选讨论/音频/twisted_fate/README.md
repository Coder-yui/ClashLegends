# 事件音频

## 2026-09-13 事件补充

来源：本机 LoL 原始 WAD / Wwise 音库只读提取；事件名经 Wwise ShortID 核验。逐文件来源 TXTP、媒体候选、增益和哈希见 `event_expansion_manifest.json`。导入器：`tools/audio/import_event_audio_expansion.py`。保留源事件层叠与增益，不做峰值归一化；死亡声统一最长 1.5 秒并按项目包络处理。离线导出不复现全部实时空间滤波和嵌套随机组合。

- `Play_sfx_TwistedFate_Destiny_OnBuffActivate`：1 个导出变体。
- `Play_sfx_TwistedFate_Destiny_OnBuffDeactivate`：3 个导出变体。
- `Play_sfx_TwistedFate_Destiny_OnCast`：2 个导出变体。
- `Play_sfx_TwistedFate_Gate_OnBuffActivate`：3 个导出变体。
- `Play_sfx_TwistedFate_Gate_marker`：3 个导出变体。
