# 正义天使模型与动画

[近战](../kayle.md) · [远程](../kayle_ranged.md) · [总索引](../README.md)

两种形态共用一个下载GLB、同一骨骼和完整动画库，包装只选择部件。原版Skin0初始隐藏表确定近战部件；Evolve3与IdlePassive事件确定16级部件。

| 内容 | 近战（1级） | 远程（16级） |
| --- | --- | --- |
| 头部 | level1头盔 | level11露脸头部 |
| 翅膀 | wings_up | wings_up、wings_mid、wings_bot |
| 武器 | 右手单把合并剑：sword_hilt_combined、sword_blade_combined | 左右手双剑：sword_hilt、sword_blade；每个部件内部均含左右两份几何 |
| 待机 / 移动 | Idle1_Base / Run1 | IdlePassive / Kayle_RunPassive_anm |
| 普攻 | kayle_attack1_anm、kayle_attack2_anm | Kayle_AttackRanged1_anm、Kayle_AttackRanged2_anm |
| 部署 / 死亡 | Respawn / Death | Respawn / Death |
| W | Spell2_0 | Spell2_0 |

Godot导入将片段名中的点改为下划线，配置使用实际导入名。两个下载的身体材质不同，16级另用“正义天使 (1).glb”的内嵌进阶身体贴图，仍不复制模型。模型缩放0.013；统一空军底部抬升不改变权威坐标。远程翅膀使用原版16级渐变色带的金白行重新着色，属于Godot简化材质适配，没有完整移植LoL动态火焰着色器。

动作只消费权威状态。命中、移动、技能治疗及溅射均不由动画回调驱动。双方共用原画材质，用阵营圈和血条识别。

## 原生部件复核（2026-09-22）

直接核对本地 LoL `Kayle.wad.client` 提取的 Skin0 与动画定义：

- `SkinMeshDataProperties.initialSubmeshToHide` 隐藏 `level11 wings_mid sword_hilt sword_blade wings_bot`，对应1级的头盔、一对翅膀和右手合并剑。
- `Evolve3` 显示 `level11 wings_bot wings_mid wings_up`、隐藏 `Level1`；其中 Swords 事件第51帧显示 `Sword_Hilt/Sword_Blade`，隐藏两个 combined 部件。`IdlePassive` 同样保持这组双剑。我们直接部署最终形态，所以直接应用最终显隐，不播放升级过程。
- 对正式GLB按每个 primitive 的索引读取蒙皮权重：`sword_blade` 左右剑骨各118个顶点，`sword_hilt` 左右各179个；`sword_blade_combined` 的94个顶点和 `sword_hilt_combined` 的180个顶点均绑定右剑骨。故双剑不是另加载第二个模型，也不是凭材质名称猜测。
- 当前 `kayle_view.gd` 的两组过滤与上述部件选择一致。`level11` 是原生部件名称，16级仍使用它，不存在需要另选的 `level16` 头部。
