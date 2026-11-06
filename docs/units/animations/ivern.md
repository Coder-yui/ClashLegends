# 翠神模型与动画

[返回单位](../ivern.md) · [单位索引](../README.md)

源模型为用户指定翠神.glb，统一缩放0.0105，保留原比例；按skin0隐藏草墙、松鼠和苹果三个默认隐藏材质。待机Idle1_Base、移动Run_Base、出生Respawn、技能Spell4、死亡Death（最长0.8秒）。

普攻使用Ivern_ranged_attack01/02，两片长均3.566667秒；源IvernBasicAttackRanged/2的castFrame均7.75，按30Hz为0.258333秒，缩放到1.5秒周期的映射节点0.108645秒，公共前摇0.11秒，误差约1.36毫秒。固定20Hz首次实际发射0.15秒；攻速同步缩放窗口与前摇。

视觉起点严格绑定原始mStartBoneName=C_Buffbone_Glb_Head_Loc；权威弹体从单位2D中心出发，两者独立。源spellCastTime另有0.32575字段，项目按已导入动画帧节点映射，不以弹体命中作为发射节点。
