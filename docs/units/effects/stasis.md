# 凝滞法术特效

[返回凝滞法术](../stasis.md)

使用本地只读 Bard.wad.client 基础皮肤R纹理：warning_decal（目标预警）、cosmic_gold（球形遮罩后的飞行星光）、explo_nova 和 ring_flare（落地扩散）。正式资源见 assets/effects/stasis/source_manifest.json；原始提取与解码源在开发素材库 03-制作中/凝滞法术。

纯表现读取权威飞行时长。轨迹从己方水晶到目标区域，高度弧线不参与命中。命中范围由SpellSystem在抵达Tick计算；材质与动画不造成伤害或状态。单位金身覆盖复用ModelVisualResources，解除恢复原材质。

基础皮肤的所有粒子层、网格柱体和原版材质曲线未完整移植。此版本是原版纹理适配，包含预警、飞行、落地和受影响对象金身；画面证据见交付报告。

金身由Godot重新实现：单位使用金色 StandardMaterial3D overlay（金属度0.8、粗糙度0.24），防御塔在原有地面/碎块裁切shader内加入金色，2D回退使用金色填充。凝滞冻结模型动画，解除移除金色；并非LoL原版金身shader或完整粒子运行器。权威抵达事件才触发落地扩散与爆炸音，结束暂无专用粒子/音频。
