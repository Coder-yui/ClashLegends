# 恕瑞玛卫队动画

[← 单位说明](../shurima_guard.md)

使用指定的黄沙士兵模型。部署使用 AzirSoldier_Spawn，待机 Idle1_Base，移动 Run，死亡 Death；攻击按 Attack1_BASE → Attack2_BASE → AzirSoldier_Attack3_anm 循环，统一适配1.6秒攻击周期。技能为即时加盾，不插入额外全身施法动作。

蓝红复用同一模型，以阵营圈区分；身体半径不受模型缩放影响。独立展台：`python3 tools/dev.py model --card shurima_guard`，可以选择、暂停和逐帧查看动作。
