# 正义天使模型与动画

[近战](../kayle.md) · [远程](../kayle_ranged.md) · [总索引](../README.md)

两种形态共用一个下载GLB、同一骨骼和完整动画库，包装只选择部件。原版Skin0初始隐藏表确定近战部件；Evolve3与IdlePassive事件确定16级部件。

| 内容 | 近战（1级） | 远程（16级） |
| --- | --- | --- |
| 头部 | level1头盔 | level11露脸头部 |
| 翅膀 | wings_up | wings_up、wings_mid、wings_bot |
| 武器 | 右手单把合并剑：sword_hilt_combined、sword_blade_combined | 左右手双剑：sword_hilt、sword_blade；每个部件内部均含左右两份几何 |
| 待机 / 移动 | Idle1_Base / Run1 | IdlePassive / Kayle_RunPassive_anm |
| 普攻 | kayle_attack1_anm、kayle_attack2_anm | Kayle_Attack3_anm、Kayle_Attack4_anm |
| 部署 / 死亡 | Respawn / Death | Respawn / Death |
| W | Spell2_0 | Spell2_0 |

Godot导入将片段名中的点改为下划线，配置使用实际导入名。两个下载的身体材质不同，16级另用“正义天使 (1).glb”的内嵌进阶身体贴图，仍不复制模型。模型缩放0.013；统一空军底部抬升不改变权威坐标。远程翅膀使用原版16级渐变色带的金白行重新着色，属于Godot简化材质适配，没有完整移植LoL动态火焰着色器。

动作只消费权威状态。命中、移动、技能治疗及焰浪均不由动画回调驱动。双方共用原画材质，用阵营圈和血条识别。

## 原生部件复核（2026-09-22）

直接核对本地 LoL `Kayle.wad.client` 提取的 Skin0 与动画定义：

- `SkinMeshDataProperties.initialSubmeshToHide` 隐藏 `level11 wings_mid sword_hilt sword_blade wings_bot`，对应1级的头盔、一对翅膀和右手合并剑。
- `Evolve3` 显示 `level11 wings_bot wings_mid wings_up`、隐藏 `Level1`；其中 Swords 事件第51帧显示 `Sword_Hilt/Sword_Blade`，隐藏两个 combined 部件。`IdlePassive` 同样保持这组双剑。我们直接部署最终形态，所以直接应用最终显隐，不播放升级过程。
- 对正式GLB按每个 primitive 的索引读取蒙皮权重：`sword_blade` 左右剑骨各118个顶点，`sword_hilt` 左右各179个；`sword_blade_combined` 的94个顶点和 `sword_hilt_combined` 的180个顶点均绑定右剑骨。故双剑不是另加载第二个模型，也不是凭材质名称猜测。
- 当前 `kayle_view.gd` 的两组过滤与上述部件选择一致。`level11` 是原生部件名称，16级仍使用它，不存在需要另选的 `level16` 头部。

## 2026-09-24：原表转场与普攻节点

本次仍只有一个 `source/kayle.glb`，两个轻量场景只是同一模型的部件选择。工作台目录将高费派生定义归入天使形态选择，不改变正式下牌3/6费规则。

原表 `mBlendDataTable` 的64位键按高32位来源、低32位目标解析（不是相反方向）：

| 原生路线 | 接入过渡 | Godot首尾混合 |
| --- | --- | --- |
| Idle1_Base → Run1；Idle_In → Run1 | Run_In（1秒，原速） | 0 / 0秒 |
| Run1 / Run_In → Idle1_Base | Idle_In | 0 / 0.1秒 |
| IdlePassive / IdleInPassive → RunPassive | Kayle_RunInPassive_anm（1秒，原速） | 0 / 0秒 |
| RunPassive / RunInPassive → IdlePassive | Kayle_IdleInPassive_anm | 0 / 0秒 |

原生 TransitionClipBlendData 仅指定过渡片段；本项目以0秒拼接其首尾，近战Idle_In→Idle1_Base另有明确0.1秒TimeBlendData。事件中的0.25秒是翼骨ConformToPath约束渐变，不能当作全身动画混合。攻击/技能出口不滥用待机转跑；未声明的边沿沿用项目既有混合策略。

远程按用户实际观察选用 Attack3、Attack4 双剑循环。原动画图确实将这两个逻辑动作绑定到 kayle_attack3/4.anm，并含双剑显隐和第5帧挥光事件；该挥光不是伤害/离弦节点。原 SpellData 中 KayleBasicAttack3/4 的静态 mAnimationName 反而是 AttackRanged2/1，不能把Spell编号直接当成动画编号。当前素材包不含完整服务器选片脚本，不能声称已还原全部原版条件。

AttackPassive 独立绑定 kayle_attackpassive.anm，AttackPassiveFast分支阈值1.9；原表未给出它何时被服务器选中的完整条件。本卡没有据名字把它套到四层被动上，保留资源但不接入。Attack3/4Fast阈值1.8，本卡基础与自身满层均低于此攻击频率，本次不添加额外Fast分支。

节点采用原生SpellData的动作参考帧，按本项目整段缩放约定适配（不是移植LoL服务器整个AttackSlot时钟）：

| 形态 / 片段 | 原生参考 | 导入片长 | 1.5秒周期映射 | 配置 |
| --- | --- | --- | --- | --- |
| 近战Attack1/2 | KayleBasicAttack/2，castFrame=9.5 | 两段均2.1666667秒（30Hz，65帧时间跨度） | 1.5×9.5/65=0.21923秒 | 0.22秒 |
| 远程Attack3/4 | 普通远程KayleBasicAttack3/4，castFrame=8；用于所选双剑动作的离弦参考 | 两段均2.1666667秒 | 1.5×8/65=0.18462秒 | 0.18秒 |

原数据还含近战spellCastTime=0.34875及角色AttackSlot的total=1.55/cast=0.3；这些属于不同参考时钟，不直接把秒值填入本项目动画窗口。以上是明确的项目映射，远程8帧应用于Attack3/4是本次换片适配，未证明原版服务器也在这两片的第8帧发射。

倍率m下前摇为配置值/m，整片播放速度为2.1666667/1.5×m；满4层时m=1.4，近战约0.1571秒、远程约0.1286秒。配置舍入误差分别+0.00077/-0.00462秒，20Hz结算另有不足一个Tick（0.05秒）的跨点误差。真正伤害/弹体由模拟执行；动画只消费序号与归一化进度。实际渲染已检查双方两种攻击、进出移动、W与死亡。

## 部署后起步

Respawn结束时正在移动：近战接Run_In，远程接Kayle_RunInPassive_anm；进入混合0.1秒，片尾接循环移动混合0秒。这条部署出口为用户要求的项目适配，不能将其表述为已证明的LoL原生Respawn边沿。双方实际渲染及片段轨迹已核对。
