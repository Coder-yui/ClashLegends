# 剑魔运行模型

- `source/ultimate.glb`：去掉Banner，保留Wings、Body、Sword、Shoulder及骨骼、贴图、动画。主源件在素材库03-制作中/剑魔/model/暗裔剑魔.glb。
- `normal_view.tscn`、`ultimate_view.tscn`：缩放0.013，仅用于初始装配及独立形态预览；战斗换形复用同一实例。
- `aatrox_view.gd`：形态部件显隐、原生动画准备、大灭被动的高度轨道。
- `weapon_snap.gd`：所选动作的Weapon→Weapon_World挂点修饰，不参与战斗。

当前动作与高度规则见 [剑魔动画](../../../docs/units/animations/aatrox.md)。批量源提取、旧导出与联调记录保留在开发素材库，不属于运行依赖。
