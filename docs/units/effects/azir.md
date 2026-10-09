# 沙漠皇帝 · 原版普攻特效

[← 返回沙漠皇帝](../azir.md) · [总索引](../README.md)

使用本地Azir.wad.client基础皮肤定义：Azir_base_BA_cas与Azir_base_BA2_cas各保留twirl、flash两层；Azir_Base_BA_Beam保留beamflow；Azir_base_BA_tar保留四层受击粒子。原版SCB网格、纹理、颜色查找图、曲线、局部偏移与旋转均从原包转换，起手及受击使用60fps原定义采样。

动画第1帧在Weapon骨骼触发两种对应起手层。第一种flash在粒子开始0.18秒出现，第二种为0.1秒；光束和目标受击由真实命中事件同时触发。原版beam的U滚动沿长度映射到纹理V，并在各图集格内重复。

原版为单粒子绑定光束：0.25秒粒子寿命、80源单位宽度、200源单位平铺长度、3×2随机起始图集、随机U偏移和每秒2单位U滚动。0.5至1.0归一时间透明度由1降到0，并通过alphaRef裁剪消隐；0.6至0.8阶段宽度缩至75%，默认纯加法混合，alphaRef=60/255。

普攻沿用通用近战式直接结算路径，保留240远程射程与对空能力。在0.25秒命中节点（20Hz下第5Tick）立即结算伤害，同时播放完整武器到目标的光束。无飞行弹体、飞行时间或途中碰撞。原版0.25秒曲线按真实表现时间播放，起点在每帧动画更新后直接采样武器骨骼姿势，避免抬杖时落后一帧；整个0.25秒内持续绑定武器，终点跟随仍存活的目标；目标死亡后保留命中落点。暂停不推进，清场释放。命中事件通过可靠通道在双方客户端播放，表现不产生额外伤害。空间按模型0.011及40像素/世界单位换算。

资源与实际绘制预热由卡牌基础resource_dependencies声明，普通槽和主动槽均可达。没有加入原版士兵W攻击光束或其他技能层，也不宣称逐像素复现LoL引擎。

[光束来源](../../../assets/effects/azir/source_manifest.json) · [起手1](../../../assets/effects/azir/cast1/source_manifest.json) · [起手2](../../../assets/effects/azir/cast2/source_manifest.json) · [受击](../../../assets/effects/azir/hit/source_manifest.json)
