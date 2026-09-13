> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# imp 音频映射

普通攻击 Attack1/2/3 共用原动画图 GhoulAttack_cast；Leap 的 jump 事件不用于普通攻击，无独立命中素材。

| 项目 cue / 动作段 | 原始事件 |
| --- | --- |
| `attack_swing[1]` | `Play_sfx_Yorick_YorickQ_GhoulAttack_cast` |
| `attack_swing[2]` | `Play_sfx_Yorick_YorickQ_GhoulAttack_cast` |
| `attack_swing[3]` | `Play_sfx_Yorick_YorickQ_GhoulAttack_cast` |
| `death` | `Play_sfx_Yorick_YorickQ_ghoul_death` |

文件/变体、源 TXTP、媒体及 SHA-256 见同目录 event_manifest.json（大纳尔为 mega_event_manifest.json）。

来源：本机 LOL_Asset_Source 的英雄基础皮肤 SFX 与 zh_CN VO；原包只读，外部库选定成品复制到 assets，并非待开发队列迁移。wwiser v20260909 + 对应共享 init.bnk；vgmstream-cli -i 解码为 PCM16 WAV，保留事件层叠和源增益，不逐文件归一化。只选择一组未知 Switch 条件，不假称材质语义；不完整复现 Wwise 实时 RTPC、滤波与嵌套随机。素材版权属于 Riot，仅作本项目学习用途。

验收状态与缺口见 docs/AUDIO_CARD_MAP.md。

2026-09-12：普通攻击改为Attack1/2/3，同用原图cast事件，替换旧leapWindup/jump配对。三段共享去重后的一个cast渲染，不宣称新增3个随机变体；旧jump文件仅保留来源归档。实际命中时间不改，音频manifest保留处理与来源，人工听感尚未确认。

2026-09-13：死亡声音超过 1.5 秒时，只保留前 1.5 秒：前 1 秒保持原音量，1–1.5 秒按振幅线性淡出；不超过 1.5 秒的素材不变。 外部原始 WAV 保留，处理前时长/哈希与输出哈希见 manifest。

## 2026-09-13 事件补充

来源：本机 LoL 原始 WAD / Wwise 音库只读提取；事件名经 Wwise ShortID 核验。逐文件来源 TXTP、媒体候选、增益和哈希见 `event_expansion_manifest.json`。导入器：`tools/audio/import_event_audio_expansion.py`。保留源事件层叠与增益，不做峰值归一化；死亡声统一最长 1.5 秒并按项目包络处理。离线导出不复现全部实时空间滤波和嵌套随机组合。

- `Play_sfx_Yorick_YorickQ_summon`：5 个导出变体。
