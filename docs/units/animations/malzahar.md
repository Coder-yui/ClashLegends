# 虚空先知模型与动画

[返回虚空先知](../malzahar.md)

使用待开发队列的“虚空先知.glb”，双阵营共用原版基础皮肤，以队伍环和血条区分。源网格约182×181×124单位，包装缩放0.015（本轮放大25%）；空军高度由通用表现层统一抬升，不改变碰撞。原皮肤未列默认隐藏子网格。

Idle1用于待机与部署，Run用于移动，Attack1/Attack2用于普攻，Spell2用于新增W的一秒施法动作，Spell4用于2.5秒引导，Death压缩到通用0.8秒死亡表现。模型与伤害完全分离。

普攻原版定义castFrame为18/16；当前GLB的Attack1/Attack2各61个采样点、间隔约1/61秒、片长0.983606秒。两套动作按源发射帧分成前摇与收势：Attack1在18/61秒、Attack2在16/61秒分段，前段均映射到权威0.35秒发射节点，后段播放0.85秒，合计1.2秒。复用通用分段攻击映射，同一片段衔接混合为0，局内攻速同步缩放；动画不触发弹体或伤害。

普通弹体权威起点仍为单位中心，视觉起点已显式绑定原版指定的C_BUFFBONE_GLB_CHEST_LOC骨骼，随模型姿态、朝向及空军高度投影。projectile_visual_height=50仅在无模型锚点时回退。R继续独立使用眼部锚点。


卡面来自Malzahar.wad.client中的基础皮肤malzaharloadscreen.tex；技能图标为Malzahar_R.dds与Malzahar_W.dds。

W源定义明确mAnimationName=Spell2、spellCastTime=0.25、spellTotalTime=1；GLB片段0.983606秒，在项目映射到1秒固定动作窗，0.25秒效果节点由权威队列触发。Skin0动画图的JointSnapEventData将weapon挂到weapon_b，使用SkeletonModifier3D在Spell2期间复刻，不改变其他片段。

冥府之握的激光由包装模型创建head骨骼附着眼部锚点，局部偏移(0,5,10)源单位，随Spell4及朝向更新；通过只读WeakRef供R表现读取，模型池复用时重新关联当前单位，与普攻原版胸部锚点分开。
