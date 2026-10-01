# 虚空女皇动画

[返回单位](../belveth.md) · [单位索引](../README.md)

需求指定的虚空女皇.glb同时包含普通和大招动作。本卡固定使用大招形态，蓝红共用同一模型；统一XYZ缩放0.011，空军离地由通用表现层校正。

## 原生大招外观

按Belveth基础皮肤的GearSkinUpgrade隐藏Head表面，将Body替换为`belveth_base_ult_main_tx.tex`解码后的`ultimate_body.png`。过滤网格与复制材质均在实例内完成，原始GLB和共享资源保持完整。没有普通形态切回过程。

## 动作

| 行为 | 当前动作 |
| --- | --- |
| 部署 | Respawn_Ult_anm |
| 待机 | Idle_Ult_anm |
| 移动 | Run_Ult_anm |
| 普攻1 | AttackSwipe1_anm，完整原生片段 |
| 普攻2 | AttackSwipe2_anm，完整原生片段 |
| 主动突进 | Spell1_ult_in_anm → Spell1_ult_out_anm，共0.4秒 |
| 主动收势 | Spell1_ult_toidle_anm，压缩到0.2秒 |
| 死亡 | 源包共用Death，1秒；仍隐藏Head并使用大招贴图 |

## 普攻时序对齐

直接引用原生大招常规攻速分支的两条完整挥击片段 `AttackSwipe1_anm` / `AttackSwipe2_anm`，各3秒、30Hz。不裁切，不组合起手片段，不补姿态采样点，也不重排关键帧；进出动作使用通用表现层的过渡。

普通攻击SpellData的castFrame=9，即原始0.3秒。选择1.5秒攻击周期，两种动作均以整段2倍速播放，映射前摇为 `0.3 ÷ 3.0 × 1.5 = 0.15秒`。攻速变化时动作与权威时间同比缩放；20Hz下0.15秒为3个固定步，基础节点无取整误差。伤害仍由权威模拟结算。

原生动画图的 `Attack1_Ult` / `Attack2_Ult` 常规分支引用 AttackSwipe 系列；超过2.11的高速分支才引用 SlowToFast 系列。本卡采用常规挥击素材；不再生成 `AttackUlt1/2` 包装动画。
原生图在大招Q中使用in→out序列，复生使用Respawn_Ult；死亡没有独立大招片段。来源为本地只读Belveth.wad.client的`data/characters/belveth/animations/skin0.bin`及皮肤skin0.bin。提取与解析证据保留在本地制作中目录的ultimate-animation-source、ultimate-texture-source。
