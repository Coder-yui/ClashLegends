# 潘森原版登场资源

运行包含六组原版系统：Spear_Impact、update_missile、Sliding_Comet、Damage_Mis、Update_Impact、Ending_Shockwave；共98个发射器定义，64项纹理、网格及骨骼代理依赖，来源与转换哈希见 source_manifest.json。

systems.json 保留原版曲线，出生偏移按三维曲线与各轴概率表读取。飞行/滑行系统使用局部 +Y 前进、+Z 向上；Ending_Shockwave使用 +X 前进、+Y 向上，并在滑行结束1.3秒才播放。世界加速度不旋转进局部坐标。静态撞地半弧网格按+X前沿校准，地面标记强制贴地。长矛由 pantheon_arrival.gd 独立保持斜插，已移除重复长矛粒子。人物使用原版 fly/slide 动作、星空纹理及橙红色参数。比例统一由 visual_metrics.gd 提供。

particles.gd 是 Godot 适配器，每系统上限220粒子；自制热浪已移除，不提供替代折射效果。未复刻完整LoL粒子引擎。原始数据位于素材库03-制作中/潘森/大招落地研究，转换源在完整落地制作与原版中体型适配目录。

2026-09-26：移除四组distot_activate及自制particle_distort shader，未使用的两张纹理退出运行目录。Damage_Mis的Air Streak 1/2横向出生偏移由0/+250改为-125/+125，额外校正网格横截面中心，使黄色空气线围绕人物滑行轴居中；前后长度、原版纹理及颜色保持。原始102项清单保留在制作源用于追溯，当前运行98项。
