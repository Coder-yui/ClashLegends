# 事件音频

## 2026-09-13 事件补充

来源：本机 LoL 原始 WAD / Wwise 音库只读提取；事件名经 Wwise ShortID 核验。逐文件来源 TXTP、媒体候选、增益和哈希见 `event_expansion_manifest.json`。导入器：`tools/audio/import_event_audio_expansion.py`。保留源事件层叠与增益，不做峰值归一化；死亡声统一最长 1.5 秒并按项目包络处理。离线导出不复现全部实时空间滤波和嵌套随机组合。

- `Play_sfx_ENV_OrderTurret_break03`：1 个导出变体。
- `Play_sfx_Env_Global_EoG_OrderNexus_death_oc`：1 个导出变体。
- `Play_sfx_Env_map11_OrderTurretMinionBasicAttack_cast`：3 个导出变体。
- `Play_sfx_Env_map11_OrderTurretMinionBasicAttack_hit`：2 个导出变体。
- `Play_sfx_Env_map11_OrderTurretMinionBasicAttack_missilelaunch`：3 个导出变体。
- `Play_sfx_Env_sruap_order_nexus_spawn`：1 个导出变体。

水晶新增 nexus_alive_loop 原版待机层（事件清单已更新），额外 −30 dB；出生声运行时在 2.5 秒窗口结束并于末尾 0.25 秒淡出，死亡立即中断。

最新：水晶出生声在前置保持结束后开始、随约 5.17 秒出生原片结束；死亡声音恢复完整原始事件，不再截断 1.5 秒，以配套约 8 秒死亡原片。待机仍额外 −30 dB。

防御塔分阶段破损：damage:stage1 → Play_sfx_ENV_OrderTurret_break01；damage:stage2 → break02；death 保留 break03。阈值与模型共用 PresentationConfig.structure_damage_stage，跨阶段只播放最终目标阶段，首次附着不补历史阶段。

2026-09-13 最新试听调整：水晶待机额外增益改为 0 dB，保留 1.5 秒出生/待机交叉淡化。防御塔最终摧毁 break03 恢复完整源事件（蓝方约 7.60 秒、红方时长见 manifest），不再套用单位死亡 1.5 秒裁剪。事件自带增益保留；未额外归一化或增大防御塔音量。
