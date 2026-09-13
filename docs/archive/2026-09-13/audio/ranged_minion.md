> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# 事件音频

## 2026-09-13 事件补充

来源：本机 LoL 原始 WAD / Wwise 音库只读提取；事件名经 Wwise ShortID 核验。逐文件来源 TXTP、媒体候选、增益和哈希见 `event_expansion_manifest.json`。导入器：`tools/audio/import_event_audio_expansion.py`。保留源事件层叠与增益，不做峰值归一化；死亡声统一最长 1.5 秒并按项目包络处理。离线导出不复现全部实时空间滤波和嵌套随机组合。

- `Play_sfx_SRU_ChaosMinionRanged_SRU_ChaosMinionRangedBasicAttack2_OnCast`：3 个导出变体。
- `Play_sfx_SRU_ChaosMinionRanged_SRU_ChaosMinionRangedBasicAttack2_OnHit`：3 个导出变体。
- `Play_sfx_SRU_ChaosMinionRanged_SRU_ChaosMinionRangedBasicAttack_OnCast`：3 个导出变体。
- `Play_sfx_SRU_ChaosMinionRanged_SRU_ChaosMinionRangedBasicAttack_OnHit`：3 个导出变体。
- `Play_sfx_SRU_OrderMinionRanged_SRU_OrderMinionRangedBasicAttack2_OnCast`：3 个导出变体。
- `Play_sfx_SRU_OrderMinionRanged_SRU_OrderMinionRangedBasicAttack2_OnHit`：3 个导出变体。
- `Play_sfx_SRU_OrderMinionRanged_SRU_OrderMinionRangedBasicAttack_OnCast`：3 个导出变体。
- `Play_sfx_SRU_OrderMinionRanged_SRU_OrderMinionRangedBasicAttack_OnHit`：3 个导出变体。

双方音库由 audio.team_overrides 选择；攻击段与模型 Attack1/Attack2 对齐。攻城兵两段共享同一基础攻击事件，红方 OnMissileCast 只在真实弹体创建时播放。尚未核实独立死亡/生成及其余发射事件，保持静音，不以其他事件代替。
