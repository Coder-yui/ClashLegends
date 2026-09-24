# 德莱厄斯血怒自身特效

项目内程序化效果：blood_rage.gdshader为模型红色脉动轮廓，blood_rage.gd为随身上升火星。不是LoL原版粒子移植，无外部纹理依赖。

场景继承ActiveBuffVisual3D，status_source=blood_rage，只消费血怒剩余时间；支持主机状态和客户端快照。0.125秒淡入淡出，死亡/换形由通用模型代理关闭，材质通过共享叠加接口组合。仅表现，不驱动状态或伤害。

[状态说明](../../../docs/units/effects/darius.md)
