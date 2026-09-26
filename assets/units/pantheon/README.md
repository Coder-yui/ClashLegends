# 潘森模型与特效

2026-09-26使用用户待开发队列的新版“不屈之枪.glb”，最终正式资源source/pantheon.glb。新版坐标已归一化，包装缩放1.05（原1.3，缩小19.23%）；旧版0.015缩放不适用。部件按原版skin0初始列表隐藏Head、Comet、Recall、Joke，保留战斗身体、双臂、头盔、披风、长枪、盾牌。

部署使用Spell4_Hit→Spell4_Hit_ToIdle；短Q使用PantheonQTap原始绑定的Spell1_Hit。动作节点和裁剪见[动画手册](../../../docs/units/animations/pantheon.md)。权威数值不由包装或shader写入。

满怒参考基础皮肤Pantheon_Base_P_enraged的附着网格、Weapon Glow/Streaks及red_pulse；登场保留原版长矛与独立骨骼代理，火光和冲击波恢复为原版六组粒子资源的 Godot 适配。效果为Godot适配，非完整Wwise/VFX引擎复刻。来源包只读，纹理转换ltk-tex-utils，原画不编辑。具体来源及SHA-256见source_manifest.json。

旧模型已放本地开发素材库04-中间产物/潘森重制/20260926，制作源在03-制作中/潘森/remake-20260926。运行目录仅放实际接入资源。

2026-09-26：死亡不再永久隐藏Head；源片第77帧交换HeadHelmet/Head，保留Helmet并按JointSnapEventData对齐C_Helmet_Snap（death_helmet.gd）。未启用的Comet/Recall/Joke保持隐藏。全部已配置战斗动作的子网格事件已核对。

当前定向彗星版本：pantheon_arrival.gd保留同一把倾斜长矛直至单位到点，不再切直立Spear_Impact。当前镜头对世界45°显著缩短投影，因此视觉倾角以高度/水平距离0.5校正；地面朝向保持己方→敌方，落点和后方120像素权威路径不变。

arrival/original_comet.gd 调度预部署五组原版粒子系统，pantheon_view.gd在到点部署时播放第六组Ending_Shockwave；r_original 包含98个发射器定义与64项实际依赖。出生偏移曲线和运动局部轴均按原版数据适配，火光及掀土拖尾沿滑行方向。visual_metrics.gd 统一主模型、长矛、人物代理和粒子的缩放比例；满怒与死亡部件继承主模型变换，血条沿通用模型投影计算。权威中体型半径18、三格路径与伤害范围不受缩放影响。

程序火焰和剪影shader已归档。自制热浪已移除；不宣称完整复刻LoL粒子引擎。所有表现只读权威进度，不派发伤害或生成。

方向与时序核对见[落地资源清单](../../../docs/units/effects/pantheon_arrival_resources.md)。Ending_Shockwave沿原始+X映射前进，冻结生成点与朝向；死亡/取消/池回收清除。粒子世界重力独立于局部朝向，任意四边形地面标记也必须贴地。

2026-09-26：移除四组distot_activate及自制particle_distort shader，未使用的两张纹理退出运行目录。Damage_Mis的Air Streak 1/2横向出生偏移由0/+250改为-125/+125，额外校正网格横截面中心，使黄色空气线围绕人物滑行轴居中；前后长度、原版纹理及颜色保持。原始102项清单保留在制作源用于追溯，当前运行98项。
