# 远古恐惧原皮模型

源SKN/SKL、纹理、动画与哈希见[source_manifest.json](source_manifest.json)。源包只读，完整源件保留开发素材库03-制作中/草间人；正式GLB为5动作子集，统一缩放0.012，完整保留全部六个原生子网格。

Chest骨骼为吸血表现起点，连续攻击连线由包装脚本根据权威目标集合生成；世界坐标网格使用单位矩阵，避免重复施加父变换。此连线为自制W式表现，不是原版粒子还原。

[草间人手册](../../../docs/units/scarecrow.md) · [远古恐惧手册](../../../docs/units/fiddlesticks.md)。

原版 `skin0.bin` 动画图按30帧/秒控制部件；`initialSubmeshToHide` 只是初始状态，不能据此删除网格。

| 动作 | 可选部件显示窗口（源动画帧） |
| --- | --- |
| idle1 | Lantern、R_Demon_Arm全程；Tongue从64帧显示，91帧隐藏 |
| run、spell2、spell2_channel | 四个可选部件均隐藏 |
| death_v2 | L_Demon_Arm、R_Demon_Arm从0帧显示，77帧隐藏 |

包装脚本在 `prepare_visual_animations()` 中拆分可选网格，保留原骨骼绑定，并为每个实例建立独立显隐轨道。切换动画恢复对应默认状态，回池清理临时部件；死亡播放加速时显隐同步加速。Body与Weapon常驻。
