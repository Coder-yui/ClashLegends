# 恕瑞玛卫队动画

[← 单位说明](../shurima_guard.md)

使用指定的黄沙士兵模型。部署使用 AzirSoldier_Spawn，待机 Idle1_Base，移动 Run，死亡 Death；攻击按 Attack1_BASE → Attack2_BASE → AzirSoldier_Attack3_anm 循环，统一适配1.6秒攻击周期。技能为即时加盾，不插入额外全身施法动作。

Run 通过移动轮播重复完整片段，每次末尾接回开头采用0.12秒姿态混合，平滑原素材首尾不一致的衔接。混合只影响模型姿态，不改变权威移动速度。

蓝红复用同一模型，以阵营圈区分；身体半径不受模型缩放影响。独立展台：`python3 tools/dev.py model --card shurima_guard`，可以选择、暂停和逐帧查看动作。
