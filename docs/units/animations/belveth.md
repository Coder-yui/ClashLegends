# 虚空女皇动画

[返回单位](../belveth.md) · [单位索引](../README.md)

需求指定的虚空女皇.glb同时包含普通和大招动作。本卡固定使用大招形态，蓝红共用同一模型；统一XYZ缩放0.011，空军离地由通用表现层校正。

## 原生大招外观

按Belveth基础皮肤的GearSkinUpgrade隐藏Head表面，将Body替换为`belveth_base_ult_main_tx.tex`解码后的`ultimate_body.png`。过滤网格与复制材质均在实例内完成，原始GLB和共享资源保持完整。没有普通形态切回过程。

## 动作与衔接

| 行为 | 当前动作 |
| --- | --- |
| 部署 | Respawn_Ult_anm，映射1秒部署窗口 |
| 待机 / 移动 | Idle_Ult_anm / Run_Ult_anm |
| 移动转待机 | Idle_Ult_In_anm，从原生第3帧（0.1秒）进入，再接Idle_Ult；进入混合0.35秒 |
| 普攻1 | 原生AttackSwipe1_in_anm → AttackSwipe1_anm |
| 普攻2 | 原生AttackSwipe2_in_anm → AttackSwipe2_anm |
| 普攻转移动 / 待机 | 对应AttackSwipe1/2_anm从原生startFrame=47（源素材30Hz，1.566667秒）接收势，再转Run_Ult / Idle_Ult |
| 主动突进 | Spell1_ult_in_anm → Spell1_ult_out_anm，0.166667 + 0.233333秒；衔接混合为0 |
| 主动转移动 | Spell1_ult_out_anm → Spell1_ult_torun_anm → Run_Ult_anm |
| 主动转待机 | Spell1_ult_out_anm → Spell1_ult_toidle_anm → Idle_Ult_anm |
| 死亡 | 不配置死亡动画，死亡时立即回收模型；8鱼照常出生 |

使用原包已有完整片段与原版指定的过渡起点，不创建合成动画，不补关键帧，不裁出新的片段文件。普攻退出路线复用原片，按项目通用过渡播放原速收势；原版退出节点另有mTickDuration=1/60，本项目不将该播放时钟误用为源素材帧位置。过渡不锁住实际移动，也不延长攻击冷却。

## 普攻时序

原版Attack1_Ult / Attack2_Ult常规分支本身就是in→swipe序列。两种起手均0.3秒、挥击均3秒；整组原始3.3秒统一2倍速播放，周期选择1.65秒。普通攻击castFrame=9、素材30Hz，原生0.3秒节点位于起手结束处，对应本项目0.15秒前摇；主片段完整播放1.5秒。源片之间原生混合为0。20Hz下前摇为3个固定步，基础节点无取整误差；攻速变化时按通用攻击时间轴同步缩放，伤害仍由权威模拟结算。

高速SlowToFast分支不用于本卡；AttackUlt1/2合成片段仍不存在。原生挥击声在主片段开始处，使用attack_swing_lead_time=0对齐前摇结束；退出时复用同名素材不会重播挥击声。

## Q与来源

原生Q的in→out保留完整片段，按0.4秒突进时钟推进；技能锁定同为0.4秒，突进结束不再保持out末姿态等待0.2秒。有可攻击建筑时直接进入普攻，否则依实际移动状态选完整ToRun（1.466667秒）或ToIdle（1.3秒）；ToRun播放期间已经正常移动，可被新普攻打断。不再将ToIdle强压为0.2秒，也不再在移动前强制经过ToIdle。进入Q的原生混合为0.05秒，in→out及out→ToRun为0。

来源：本地只读Belveth.wad.client的data/characters/belveth/animations/skin0.bin与皮肤skin0.bin。普攻退出节点0x79866517 / 0x05d356ba，Q退出0xd1391269 / 0x113ac9f6，移动转待机入口0xbf228a5c。解析证据保留在本地制作中ultimate-animation-source；本轮核对摘录保存在中间产物“虚空女皇动作音频核对-20261002”。
