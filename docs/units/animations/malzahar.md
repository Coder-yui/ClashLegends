# 虚空先知模型与动画

[返回虚空先知](../malzahar.md)

使用待开发队列的“虚空先知.glb”，双阵营共用原版基础皮肤，以队伍环和血条区分。源网格约182×181×124单位，包装缩放0.015（本轮放大25%）；空军高度由通用表现层统一抬升，不改变碰撞。原皮肤未列默认隐藏子网格。

Idle1用于待机与部署，Run用于移动，Attack1/Attack2用于普攻，Spell2用于新增W的一秒施法动作，Spell4用于2.5秒引导，Death用于1秒死亡表现。模型与伤害完全分离。

普攻原版定义castFrame为18/16；按60fps、GLB片长0.983606秒、项目1.2秒攻击周期映射为0.366/0.325秒，统一0.35秒（误差约0.025秒以内）。原始spellCastTime不直接替代动画帧映射。

卡面来自Malzahar.wad.client中的基础皮肤malzaharloadscreen.tex；技能图标为Malzahar_R.dds与Malzahar_W.dds。

W源定义明确mAnimationName=Spell2、spellCastTime=0.25、spellTotalTime=1；GLB片段0.983606秒，在项目映射到1秒固定动作窗，0.25秒效果节点由权威队列触发。Skin0动画图的JointSnapEventData将weapon挂到weapon_b，使用SkeletonModifier3D在Spell2期间复刻，不改变其他片段。
