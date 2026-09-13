# 缺失音效素材搜索结果

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

2026-09-13。范围排除英雄部署声、所有走路声和明确取消的音频。只读搜索本机 LoL 原始音库；未修改卡牌或实战音频配置。候选已实际解码、检查非静音，不把事件名存在等同于可用 WAV。

## 可明确对应的素材

- **太阳圆盘普攻三层**：AzirSunDisc 基础皮肤粒子直接引用 `Play_sfx_Env_map11_ChaosTurretChampionBasicAttack_cast`、`Play_sfx_Env_TurretBasicAttack_missilelaunch`、`Play_sfx_Env_TurretBasicAttack_hit`。三层均在共享建筑音库匹配事件 ShortID、找到媒体并解码。原表确实使用 Chaos cast，不按本项目阵营自行猜换色音。
- **太阳圆盘生成/消失候选**：当前 Azir 基础音频清单及音库有 `Play_sfx_Azir_AzirObeliskSound_OnBuffCast`（两组随机层，后组延迟 3.5 秒）和 `...OnBuffDeactivate`（消失/结束）。已渲染约 9.79 秒和 4.97 秒样例。它们与旧 Spawn 动画表中的 `AzirObelisk_buffcast/buffactivate` 名称不同：旧名未在已查音库中匹配，不能把它们说成同名完整复刻。生成/消失音可用于圆盘，但正式接入需匹配当前部署/死亡动画并试听。
- **墓碑持续声**：`Play_sfx_Yorick_YorickWWallLife_OnBuffActivate`，有持有层及随机循环层，原事件额外增益为 −24 / −30 dB；试听导出约 23.41 秒，不代表墙体必须存活这么久。具备可用素材，正式接入应按墓碑生存、销毁和清场停止。

## 自定义技能的替代候选

这些声音真实来自 LoL，但并非本项目自定义技能的原生专属音。

| 本项目用途 | 已找到并解码的候选 | 限制 |
| --- | --- | --- |
| 冰冻施放、生效、消散 | 丽桑卓 W：`LissandraW_OnCast`、`LissandraWFrozen_OnBuffActivate`、`LissandraWShards_buffdeactivate` | 原技能为冰霜范围禁锢；不是本项目冰冻法术，持续时间/强化减速需另适配 |
| 皮克斯仙灵汲取 | 弗拉基米尔 Q：`VladimirQ_OnCast`、`VladimirTransfusionHeal_OnHit` | 汲取/回血语义匹配，但血魔法音色未必适合仙灵；不能给每次命中直接叠完整长尾 |
| 近战兵列阵突击、超级兵超级冲锋 | 希维尔 R：`SivirR_OnCast`、`OnBuffActivate`、`OnBuffDeactivate` | 是加速状态候选，不包含本项目额外伤害/护盾全部含义；获盾声不自动加回 |
| 炮车兵超载炮击 | 吉格斯 Q：`ZiggsQ_hit` | 爆炸冲击候选，无需套入吉格斯投弹施放/弹跳声 |
| 远程兵奥术齐射 | 共享 `TurretBasicAttack_hit` 魔法冲击 | 只是已验证的可复用音色，并非原版“小兵奥术齐射”音；应与普通命中听感区分后决定 |

墓碑亡者集结的生成结果已有小鬼出生音，没有确认独立的墓碑本体主动施法声；不把掘墓本人 W 施法或 VO 自动挪给墓碑。

## 尚未找到明确对应的独立素材

- 四种小兵的基础出生/死亡、远程兵及蓝方炮车的额外独立发射层：查看双阵营基础皮肤/动画表、共享小兵事件导出与候选 ShortID，尚不能确认匹配；已有普攻素材不受影响。其他模式/皮肤的 minion jump 不属于当前对象。
- 皮克斯独立出生/死亡：Lulu 音库的 `Death3D` 属于露露本人，不能当作皮克斯死亡。FaerieOverride_blink / FaerieShield / FaerieBurn 也不能仅凭名字改当出生或死亡。
- 小鬼独立普通命中、凤凰蛋独立碎壳：本轮未确认新匹配；已有小鬼普攻出手及蛋击破死亡声保留。
- 防御塔普通出生：仅见已知 NexusTurret Respawn 类事件，不能直接认定对应当前普通防御塔初始生成。

“尚未找到”限定本机当前版本与已核验路径，不断言 LoL 所有版本都没有素材。

## 可听的候选样例

以下每项导出一个选定事件样例，不穷尽随机组合。源增益保留，未归一化；部分渲染到达 PCM 峰值上限，需要选定后检查并处理混音，不能当作最终接入成品。循环只作单次试听渲染。

- **太阳圆盘生成**：[试听 9.79 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Azir_AzirObeliskSound_OnBuffCast.wav) — `Play_sfx_Azir_AzirObeliskSound_OnBuffCast`
- **太阳圆盘消失**：[试听 4.97 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Azir_AzirObeliskSound_OnBuffDeactivate.wav) — `Play_sfx_Azir_AzirObeliskSound_OnBuffDeactivate`
- **太阳圆盘出手**：[试听 2.95 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Env_map11_ChaosTurretChampionBasicAttack_cast.wav) — `Play_sfx_Env_map11_ChaosTurretChampionBasicAttack_cast`
- **太阳圆盘发射**：[试听 1.08 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Env_TurretBasicAttack_missilelaunch.wav) — `Play_sfx_Env_TurretBasicAttack_missilelaunch`
- **太阳圆盘命中**：[试听 0.83 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Env_TurretBasicAttack_hit.wav) — `Play_sfx_Env_TurretBasicAttack_hit`
- **墓碑持续**：[试听 23.41 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Yorick_YorickWWallLife_OnBuffActivate.wav) — `Play_sfx_Yorick_YorickWWallLife_OnBuffActivate`
- **冰冻候选施放**：[试听 2.67 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Lissandra_LissandraW_OnCast.wav) — `Play_sfx_Lissandra_LissandraW_OnCast`
- **冰冻候选生效**：[试听 0.63 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Lissandra_LissandraWFrozen_OnBuffActivate.wav) — `Play_sfx_Lissandra_LissandraWFrozen_OnBuffActivate`
- **冰冻候选消散**：[试听 1.67 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Lissandra_LissandraWShards_buffdeactivate.wav) — `Play_sfx_Lissandra_LissandraWShards_buffdeactivate`
- **汲取候选施放**：[试听 3.78 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Vladimir_VladimirQ_OnCast.wav) — `Play_sfx_Vladimir_VladimirQ_OnCast`
- **汲取候选回血**：[试听 4.75 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Vladimir_VladimirTransfusionHeal_OnHit.wav) — `Play_sfx_Vladimir_VladimirTransfusionHeal_OnHit`
- **冲锋候选施放**：[试听 3.54 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Sivir_SivirR_OnCast.wav) — `Play_sfx_Sivir_SivirR_OnCast`
- **冲锋候选持续**：[试听 5.00 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Sivir_SivirR_OnBuffActivate.wav) — `Play_sfx_Sivir_SivirR_OnBuffActivate`
- **冲锋候选结束**：[试听 1.93 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Sivir_SivirR_OnBuffDeactivate.wav) — `Play_sfx_Sivir_SivirR_OnBuffDeactivate`
- **炮击候选爆炸**：[试听 2.13 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Ziggs_ZiggsQ_hit.wav) — `Play_sfx_Ziggs_ZiggsQ_hit`
- **齐射候选魔法命中**：[试听 0.83 秒](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/Play_sfx_Env_TurretBasicAttack_hit.wav) — `Play_sfx_Env_TurretBasicAttack_hit`

## 证据与复现

- 本机只读来源：`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/` 下 Azir、Yorick、Lulu、Lissandra、Vladimir、Sivir、Ziggs 与 Map11/Common。
- 太阳圆盘 Spawn/Death 动画表：`/Users/czh/Tools/lol-asset-tools/missing_audio_review/data/characters/azirsundisc/animations/skin0.rito`；普攻粒子同目录的 skins/skin0.rito。
- 对应事件图：`card_audio_batch/azir/txtp`、`card_audio_batch/yorick/txtp`、`shared_audio_review/txtp` 以及 `missing_audio_review/candidates/*/txtp`，均位于上述工具目录。
- 导出清单：[manifest.json](/Users/czh/Tools/lol-asset-tools/missing_audio_review/auditions/manifest.json)，含原 TXTP、事件 ID、候选媒体、时长、峰值和 SHA-256。导出脚本保存在同级上层 `export_candidates.py`。
- 本轮只做素材查找与试听样例导出，没有更改游戏文件中的 audio 域、声音时序或玩法；没有宣称完成实战听感验收。
