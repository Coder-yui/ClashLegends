# 凝滞法术特效

[返回凝滞法术](../stasis.md)

使用本地只读 Bard.wad.client 基础皮肤R纹理：warning_decal（目标预警）、cosmic_gold（球形遮罩后的飞行星光）、explo_nova 和 ring_flare（落地扩散）。正式资源见 assets/effects/stasis/source_manifest.json；原始提取与解码源在开发素材库 03-制作中/凝滞法术。

纯表现读取权威飞行时长。轨迹从己方水晶到目标区域，高度弧线不参与命中。命中范围由SpellSystem在抵达Tick计算；材质与动画不造成伤害或状态。单位凝滞附着网格覆盖由ModelVisualResources管理，解除恢复原材质。

基础皮肤的所有粒子层、网格柱体和原版材质曲线未完整移植。此版本是原版纹理适配，包含预警、飞行、落地和受影响对象金身；画面证据见交付报告。

2026-10-01模型表现改为按LoL原定义移植的附着网格两层：`Temp_Avatar` 使用原版 `Bard_Base_P_speed_swirl_mult`，模型放大1.02、UV纵向每秒滚动0.4；`Gold_Avatar1` 使用原版中娅swirl纹理，模型放大1.01。层透明度使用原定义常量与曲线平台值的乘积0.700008²。已移除旧StandardMaterial3D纯金色覆盖。

Godot使用两遍shader适配；防御塔在既有裁切shader中合成同组纹理，避免显露隐藏塔体或改变独立碎块。动画姿态仍随权威凝滞冻结/恢复。该版本用于预览原版附着网格思路，并非完整LoL粒子运行器：未移植原版特殊英雄子网格过滤、入退场透明度曲线及周边粒子发射器；持续时间沿用项目2/3秒，解除直接移除。
