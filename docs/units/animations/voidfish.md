# 虚空鱼动画

[返回单位](../voidfish.md) · [单位索引](../README.md)

原模型使用需求指定的虚空女皇 (1).glb；双方共用模型，阵营标识由通用表现提供。统一XYZ缩放0.014，空军离地高度由通用表现层校正。

待机与部署 Idle1，移动 Run，近战 attack_1_anm，死亡 Death（0.6秒）。按原生 skin0.initialSubmeshToHide 隐藏 Ranged 表面，只保留 Melee；每实例过滤，不修改共享资源。

## 命中节点

源定义：`Game/DATA/FINAL/Champions/Belveth.wad.client` 中 `data/characters/belvethvoidling/belvethvoidling.bin`。GLB 动画时间采样间隔约1/30秒。

BelvethVoidlingMeleeAttack 的 castFrame=14.1，即0.47秒；attack_1长1.433333秒（43帧）。映射到1.25秒周期为0.47÷1.433333×1.25=0.409884秒，前摇0.41秒，误差小于0.2毫秒。

最终结算由20Hz跨节点的Tick触发，最多另有一个Tick量化误差；动画不能触发伤害。原生AttackSlot的攻击时间比不是此处整片缩放依据。

女皇死亡召唤的八鱼不叠加部署锁，出生Idle1完整片段缩放到正常散开0.45秒；延长外抛不拉长出生动画。动画结束不释放仍有效的控制，也不能反过来延长逻辑锁。

收尾核查：近战与远程SpellData的castFrame均为14.1，但分别表示近战命中与远程弹体发射，不能视为相同的真实命中时机。本卡只使用近战attack_1；原版近战还有其他随机动作，本卡未启用。原生近战出手SoundEvent位于动作起点，远程Ranged_Attack1的出手声位于第11帧，不混用。实战首击可能在0.45秒Tick结算（相对0.41秒前摇晚0.04秒），属于现有20Hz量化；后续周期表现时钟保留跨节点余量。
