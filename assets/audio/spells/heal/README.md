# 事件音频

> 2026-10-04 原版增益重导：当前文件与加工参数以 `assets/audio/original_gain_manifest.json` 为准；下面历史文字中的额外增益、制作余量及旧哈希说明已被本次重导替代。工具主增益、后期固定增益和事件播放补偿均为 0 dB；原事件内部增益保留。


## 2026-09-13 事件补充

来源：本机 LoL 原始 WAD / Wwise 音库只读提取；事件名经 Wwise ShortID 核验。逐文件来源 TXTP、媒体候选、增益和哈希见 `event_expansion_manifest.json`。导入器：`tools/audio/import_event_audio_expansion.py`。保留源事件层叠与增益，不做峰值归一化；死亡声统一最长 1.5 秒并按项目包络处理。离线导出不复现全部实时空间滤波和嵌套随机组合。

- `Play_sfx_SummonerHeal_OnCast`：3 个导出变体。
