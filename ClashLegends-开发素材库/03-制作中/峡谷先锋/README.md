# 峡谷先锋制作记录

正式模型、卡面与音频已接入 `assets/`；玩法、动画和音频以 `docs/units/rift_herald.md`、`docs/units/voidmite.md` 及其专项页为准。

- `promotion.json`：素材迁移记录。
- `rift_herald_native_blends.json`、`voidmite_native_blends.json`：原版动画混合表。
- `audio_config.json`：音频加工配置；当前正式事件配置在逐卡定义中。
- `lol-source/source_manifest.json`、`lol-source/timing_mapping.json`：来源和原版时序依据。
- `lol-source/assets/`、`lol-source/data/`、`audio/` 与加工日志为本地批量提取/转换副本，不提交；外部 Map11 源包保持只读。
- 全量试听候选保留在 `02-候选讨论/峡谷先锋与虚空蠕虫全量音频/`，使用现有 `tools/dev.py audio` 展示。
- 渲染截图、录音和验证日志位于素材库 `04-中间产物/`，不作为运行依赖。
