# 卑尔维斯动画

[返回单位](../belveth.md) · [单位索引](../README.md)

原模型使用需求指定的虚空女皇.glb；双方共用模型，阵营标识由通用表现提供。统一XYZ缩放0.011，空军离地高度由通用表现层校正。

待机 Idle1_Base，移动 RunClosed_anm，部署 Respawn，死亡 Death（1秒）。包装仅将 Attack_Slow1a + Attack_Slow1b、Attack_Slow2a + Attack_Slow2b 拼成完整普攻，分别命名 Attack1/2。突进使用 Spell1_In，收势使用 Spell1_ToIdle 前0.4秒压到0.2秒。Body、Head均为原生可见表面，无额外隐藏部件。

## 命中节点

源定义：`Game/DATA/FINAL/Champions/Belveth.wad.client` 中 `data/characters/belveth/belveth.bin`。GLB 动画时间采样间隔约1/30秒。

普通攻击 castFrame=9，即0.3秒；两个拼接片段均长2.966667秒（89帧）。映射到1.5秒攻击周期为0.3÷2.966667×1.5=0.151685秒，公共前摇0.15秒，误差约1.7毫秒。

最终结算由20Hz跨节点的Tick触发，最多另有一个Tick量化误差；动画不能触发伤害。原生AttackSlot的攻击时间比不是此处整片缩放依据。
