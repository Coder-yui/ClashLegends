> 音频素材说明整理前快照，含历史修改。当前映射以逐卡 audio 域为准。

# 事件音频

## 2026-09-13 事件补充

来源：本机 LoL 原始 WAD / Wwise 音库只读提取；事件名经 Wwise ShortID 核验。逐文件来源 TXTP、媒体候选、增益和哈希见 `event_expansion_manifest.json`。导入器：`tools/audio/import_event_audio_expansion.py`。保留源事件层叠与增益，不做峰值归一化；死亡声统一最长 1.5 秒并按项目包络处理。离线导出不复现全部实时空间滤波和嵌套随机组合。

- `Play_sfx_3190Active_OnCast`：1 个导出变体。
- `Play_sfx_3190Shield_OnBuffActivate`：1 个导出变体。

用户试听后：shield:applied 额外 −24 dB，从获盾目标坐标播放；WAV 原始增益保留。

## 2026-09-13 太阳圆盘与墓碑正式接入

太阳圆盘已接入 AzirObeliskSound_OnBuffCast 生成、OnBuffDeactivate 消失、共享防御塔出手/发射/命中，原盾技能施放声保持，获盾声仍不使用。来源与处理见各音频目录 building_event_manifest.json；导入器 tools/audio/import_sun_disc_tombstone_audio.py。

- 当前保留 1 秒权威部署。Spawn 原片约 4.9667 秒适配这 1 秒；生成声音的前 4.9667 秒保音高压缩到 1 秒，其后的消散尾音保持原速，原声音内 3.5 秒的延迟层约在 0.705 秒进入。旧动画表的 Obelisk_buffcast/buffactivate 与当前声音银行 ObeliskSound 事件名称不同，采用语义/时序适配，不宣称恢复原客户端脚本。
- Death 恢复原片约 3.6667 秒；消失声完整播放，不套单位死亡 1.5 秒截断。权威死亡即时生效，动画和尾音不延迟伤害、碰撞或寿命结算。
- Attack1_BASE / Attack2_BASE 都启用，沿用项目确定交替选择；按原图 Disk 遮罩仅保留 Chest_Loc / Obelisk_Tip 骨骼轨道，不驱动基座。库在实例中复制，原 GLB 保持不变。
- Idle 参考原图 60/40 分支：三次简单 Base、两次 Base→Idle2→Base，展开成 9 段确定循环；没有新增原版随机选择器。相关片段间采用原表零混合。
- 普攻原始事件增益保留，项目三层分别额外 −6 dB，为双方同时攻击预留混音余量。出手读攻击序号，发射读真实弹体创建，命中读真实碰撞；音频不驱动弹道或伤害。
- 墓碑已接 YorickWWallLife_OnBuffActivate 持续层：部署结束进入待机开始，结束续播，冻结/眩晕暂停，死亡/销毁/清场停止。项目墓碑普通和瞬时召唤主动均可保持待机，不把生存循环当普攻。

验证：完整 mechanics 通过，新增墓碑持续声生命周期检查，更新太阳圆盘双攻击遮罩及待机循环回归。双阵营实际渲染、事件日志和混音录音来自 tools/demos/sun_disc_tombstone_review.gd，输出 /tmp/clash-sun-disc-tombstone。主观听感仍需用户复听。

### 本轮试听调整

- 死亡动画仅播放 Death 原片 0–2 秒，压缩为 0.8 秒（2.5 倍速）；完整消失音暂不裁剪，供用户试听选段。
- 日耀庇护增加黄色扩散波：中心向自身半径 40 + 技能/攻击射程 220 的边界扩散，约 0.28 秒到达、0.5 秒完全淡出。沿用去重的可靠 shield:cast 表现事件，主机/客户端均消费；音频静音不会阻止特效，波前不驱动加盾。清场时一起清理。
- 临时音频板合并 building_event_manifest，现可按 death 试听完整消失声的两个变体（约 4.97 / 5.09 秒），带播放器时间标识。
- 完整机制回归通过；实际双阵营画面见 /tmp/clash-sun-disc-tombstone/shield_wave.png，死亡片段截图与录音同目录。

最新死亡音选择：两个消失音变体均仅取原始前 2 秒，以 atempo=4/3 保音高压缩到精确 1.5 秒，不添加旧的 1–1.5 秒死亡淡出包络；试听板与实战使用同一文件。死亡动画仍为前 2 秒压缩到 0.8 秒。
