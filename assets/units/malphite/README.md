# 熔岩巨兽模型来源

源模型：`ClashLegends-开发素材库/01-待开发/卡牌模型/熔岩巨兽.glb`，由用户指定。正式副本为source/malphite.glb；原包保持不变。

基础皮肤源件来自本机只读Malphite.wad.client。原模型/动画/BIN与哈希保留在开发素材库03-制作中/熔岩巨兽。岩石纹理为assets/characters/malphite/skins/base/malphite.tex，破盾纹理为同皮肤particles/malphite_base_z_malphite_molten.tex。卡面为基础皮肤malphiteloadscreen.tex，未使用重制概念图或其他皮肤。

包装缩放2.50，原SKN→GLB为0.0085；源皮肤skinScale为1.75，所以原生粒子缩放为0.0085×2.50÷1.75≈0.0121429。尺寸唯一配置为visual_scale.gd，不做相机投影补偿。常驻有盾外观用原岩石纹理，破盾切原熔岩纹理；完整原始动态材质流火/Fresnel不在当前Godot基础材质内。

E单独采用0.01等比缩放，匹配160像素范围；被动护盾仍随2.50模型换算。E的14个启用层名称与纹理逐层匹配源定义，Skin16拳击碎石依赖由基础皮肤原文件引用，并非误接其他皮肤。通用nova枪芒不再叠加到专属原版特效。
