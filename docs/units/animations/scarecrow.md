# 草间人（建筑卡）：模型动画

[返回单位](../scarecrow.md) · [返回总索引](../README.md)

使用费德提克原皮SKN/SKL及原生动作。原始主体约221单位高，统一XYZ缩放0.012；完整保留Body、Weapon、Lantern、Tongue、L_Demon_Arm与R_Demon_Arm，按原版动画事件控制可选部件。待机idle1、移动run、攻击spell2_channel持续循环；直接持续结算无离弦节点。死亡death_v2原长3.933秒，压缩至0.8秒。

吸血连线为本项目制作的W式红色流动曲线，从Chest骨骼连到权威同步目标，仅作表现。尚非原版W粒子逐层复现；没有添加末跳动作或末跳伤害。实际渲染验收结果见交付记录。

原版 `skin0.bin` 动画图按30帧/秒控制部件；`initialSubmeshToHide` 只是初始状态，不能据此删除网格。

| 动作 | 可选部件显示窗口（源动画帧） |
| --- | --- |
| idle1 | Lantern、R_Demon_Arm全程；Tongue从64帧显示，91帧隐藏 |
| run、spell2、spell2_channel | 四个可选部件均隐藏 |
| death_v2 | L_Demon_Arm、R_Demon_Arm从0帧显示，77帧隐藏 |

包装脚本在 `prepare_visual_animations()` 中拆分可选网格，保留原骨骼绑定，并为每个实例建立独立显隐轨道。切换动画恢复对应默认状态，回池清理临时部件；死亡播放加速时显隐同步加速。Body与Weapon常驻。
