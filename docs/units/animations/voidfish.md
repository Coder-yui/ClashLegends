# 虚空鱼动画

[返回单位](../voidfish.md) · [单位索引](../README.md)

原模型使用需求指定的虚空女皇 (1).glb；双方共用模型，阵营标识由通用表现提供。统一XYZ缩放0.014，空军离地高度由通用表现层校正。

待机与部署 Idle1，移动 Run，近战 attack_1_anm，死亡 Death（0.6秒）。按原生 skin0.initialSubmeshToHide 隐藏 Ranged 表面，只保留 Melee；每实例过滤，不修改共享资源。

## 命中节点

源定义：`Game/DATA/FINAL/Champions/Belveth.wad.client` 中 `data/characters/belvethvoidling/belvethvoidling.bin`。GLB 动画时间采样间隔约1/30秒。

BelvethVoidlingMeleeAttack 的 castFrame=14.1，即0.47秒；attack_1长1.433333秒（43帧）。映射到1.25秒周期为0.47÷1.433333×1.25=0.409884秒，前摇0.41秒，误差小于0.2毫秒。

最终结算由20Hz跨节点的Tick触发，最多另有一个Tick量化误差；动画不能触发伤害。原生AttackSlot的攻击时间比不是此处整片缩放依据。
