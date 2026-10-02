# 蛮族之王运行模型

source/tryndamere.glb保留原21条动作和模型。包装缩放3.1，AnimationPlayer使用独立animations.res：保留源动作，新增DeployIdle（Idle1最后1秒）和HeldAttack1/HeldAttack2/HeldCrit（首帧保持0.4秒＋完整攻击1.07秒＋末帧保持0.23秒）。动画库使用Godot导入后的原始姿势生成，绕过GLB优化器对静止边界关键帧的删除，普通与暴击均逐骨骼检查。

制作脚本位于本地素材库03-制作中/蛮族之王/bake_animation_library.gd。无隐藏子网格，不改变权威半径。来源和产物摘要见animation_manifest.json。

[当前动画与命中节点](../../../docs/units/animations/tryndamere.md)。
