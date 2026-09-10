# 盖伦原皮：当前玩法音频

已移除旧的 24 份实验 WAV 及其导入文件；现在使用本次解析的事件组合 WAV，共 42 份。原始完整素材库保留在项目外，不会整包导入。

| 游戏触发 | 原始事件（省略 Play_sfx_Garen_） | 变体数 |
| --- | --- | --- |
| Attack1 / Attack2 出手 | GarenBasicAttack_OnCast / GarenBasicAttack2_OnCast | 4 + 4 |
| 普攻/强化普攻实际命中 | GarenBasicAttack_OnHit | 16 |
| 致命打击准备状态出现 | GarenQ_OnCast | 3 |
| Spell1 强化出手（替代普通挥击） | GarenQAttack_OnCast | 1 |
| judgment / Spell3_0 开始 | GarenE_OnCast | 3 |
| judgment 持续旋转层（空转也播放） | GarenE_OnBuffActivate | 3 |
| judgment 结束 | GarenE_OnBuffDeactivate | 3 |
| 审判实际伤害脉冲（每脉冲至多一次） | GarenE_hit | 4 |
| Death 开始 | Death3D_cast | 1 |

## 接入约定

- CardDB.audio 登记所有路径、变体池与音量；GameAudioManager 只消费动作序号、强化状态、死亡信号和真实命中事件。
- 两个技能仍由原有备战选择决定；没有配置让两者同时释放。普通攻击命中共享素材，不把暴击或 R 命中声冒充 Q 命中。
- 没有给部署、待机、跑步凭空配声音；未引入 W、R、被动、表情或 VO。
- judgment:sustain 随起手同时启动，随机选择约 3.49/3.56/3.64 秒的 BuffActivate 原片段，按单次播放而非无限循环；由单位持有独立播放器，位置跟随角色。3 秒技能结束时停止该层并播放收尾；死亡/销毁立即停止且不补播收尾，替换动作也停止旧层。冻结/眩晕期间该层暂停并随动作恢复。命中声独立叠加，没有敌人也有旋转声音。
- 这复刻主要播放组织，不宣称完整还原 LOL 动态滤波/停止淡出参数；起手等短音仍自然保留尾音。持续层最多 24 路，满时回收最早一条，不抢占短音池。
- 攻击序号/技能动作由快照同步；审判真实命中通过 authority-only RPC 重放。声音丢失不影响伤害。
- WAV 保留事件解析后的层级增益，CardDB 额外增益为 0 dB，没有逐文件峰值归一化。
- OnHit 的四个数值 Switch 分支尚未恢复材质名称，目前作为共享随机池使用，不能宣称是已识别的“建筑材质分支”。文件保留数值 ID，后续可按确认结果细分。

## 来源与重现

源目录：`/Users/czh/Tools/lol-asset-tools/garen_base_audio/event_wav/`。
源包：LOL_Asset_Source 的 Garen.wad.client 原皮 SFX Audio/Events BNK，结合 skin0.bin 事件名及 init.bnk。
工具：wadtools、wwiser、vgmstream；导出保留可解析事件层级，不能完整复现 Wwise 运行时滤波、动态音高及全部嵌套随机组合。

`event_manifest.json` 记录项目文件 → 原始事件名/ShortID → 源预览 → 事件关联 WEM 集合。
其中 media_ids 是整个事件的候选来源，不表示每个变体包含全部 WEM。
文件按项目 snake_case 命名；rN、Switch 数字与 d（wwiser 重复事件标记）均保留。
恢复的是事件名，不是 Riot 工程里的原 WAV 名。

可运行 `python3 tools/import_garen_audio.py` 从上述完整库重新复制这 42 份素材；不会删除或改变源库。
顺序试听 Q/E：`Godot --path . --script tools/demos/garen_audio_demo.gd`；每段分别生成角色并使用正式技能/表现入口，日志显示实际音频事件，截图写入系统临时目录。
仅供学习原型使用；商业使用需取得素材权利人的许可。
