# 冰冻 · 冰霜护手地面效果

正式消费者：`scripts/presentation/freeze_ground_3d.gd`，由BattlePresentation3D读取SpellSystem的表现窗口。冻结3秒；强化后额外维持2秒双减速阶段。原权威半径110不变。

`ice_mask.png`来自只读本地LoL源库Global.wad.client的`assets/items/6662/particles/global_item_atlas_indicator_ice_mask.tex`，使用ltk-tex-utils解码。`ice_ground.gdshader`将原版遮罩的冰块与裂缝映射为透明蓝色冰面，首帧直接显示完整冰纹，冻结与强化后2秒使用同样材质，到期直接移除；这是Godot贴地适配，不包含原版高处粒子或模型冰柱。来源哈希见[source_manifest](source_manifest.json)。

四角由相机逆投影到y=0.04，画面覆盖范围对齐权威圆形。透明材质保留深度测试、不写深度、不投阴影，人物正常遮住脚下冰纹。资源与材质只负责画面，不驱动控制、伤害、移动或联网。网格与材质按同时可见区域数复用；清场隐藏。外圈由施法阵营选择蓝色或红色，冻结与双减速阶段保持相同阵营颜色；内部冰纹不随阵营染色。对象不再附加二维冰冻蓝圈。

原始提取、转换与联调副本均位于本地开发素材库；只将本目录运行依赖接入assets。技能图标使用同包`6662_tank_t3_iceborngauntlet.dds`，接入assets/skills/freeze_0.png。

`attached_frost.gdshader`用于Unit型建筑的淡蓝覆盖，颜色和透明度与人物原叠层一致。参考凝滞对凹面废墟的贴合方式，不缩放网格，仅施加微小深度偏移；不染色附属粒子。防御塔在现有裁切材质内混合相同淡蓝色，仅对塔身表面启用，金身优先、解除按仍有效状态恢复；碎块/废墟显隐和动画时钟继续沿用原所有者。减速/减攻速不选择这层材质。
