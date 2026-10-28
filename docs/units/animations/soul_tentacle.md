# 灵魂触手 · 动画

[← 返回灵魂触手](../soul_tentacle.md) · [总索引](../README.md)

使用IllaoiMinion基础皮肤原生骨骼与动作，统一缩放0.01，不按相机压平或拉伸。

| 状态 | 原始动作 | 源时长 |
| --- | --- | --- |
| 部署 | illaoiminion_spawn | 2.533秒 |
| 待机 | illaoiminion_idleangry | 8.967秒 |
| 攻击 | illaoiminion_attack1 | 2.633秒 |
| 死亡 | illaoiminion_death | 1.633秒，项目压缩至0.8秒 |

原动画图Attack1_BASE的拍地事件在第22帧，按30Hz为0.733秒；动作映射至2.65秒间隔后约0.738秒，20Hz权威节点为0.75秒。强化攻速×1.5，前摇0.5秒；不增加新的攻击动作。动作只能读取权威攻击序号和进度，不能生成伤害。

[模型包装场景](../../../assets/units/soul_tentacle/soul_tentacle_view.tscn)

缩放依据为原版IllaoiPassive的PassiveTentacleWidth=200，映射到2格（80像素），即2/200=0.01。模型与粒子同倍率，伤害长度独立为9格；不按长度二次拉伸模型。
