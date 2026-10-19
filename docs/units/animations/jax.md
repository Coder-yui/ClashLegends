# 武器大师动画

[返回武器大师](../jax.md) · [单位索引](../README.md)

使用需求指定的武器大师.glb。当前GLB相对原SKN的三轴缩放实测均为0.0085，模型包装再统一缩放1.25，与稍大档德莱厄斯同机位比较；权威半径独立为21。基础皮肤定义默认隐藏Bluefish、Goldfish，包装只移除这两个表面，保留身体、武器、骨骼和动画。

部署2秒，继续使用Respawn、待机Idle1_Base、移动Run_Base；普通攻击交替Attack_1_anm与Attack_2_anm。反击风暴先以0.4秒Spell3_Run_Intro_anm起手，再按移动状态接Spell3_Idle/Spell3_Run；期间普攻使用Spell3_Attack1/2；死亡Death源片5秒，压缩上限0.8秒。原始头发ConformToPath修饰未复现，使用导入骨骼动画。

普攻原版castFrame=10.5，按30fps为0.35秒；两套源动作均2.166667秒，映射1.4秒周期后为0.226154秒，配置0.23秒，20Hz结算到0.25秒。E期间攻击片长2.333333秒，统一前摇对应约0.21秒，近似误差0.02秒。源spellCastTime=0.40855与castFrame不相同，本项目以castFrame映射作者动作，不声称复现原游戏完整攻速求解。

动画不驱动命中、伤害或免疫计时。双方、同档尺寸、技能中普攻和死亡清场截图见本任务交付记录。

原版animationGraph的TransitionClipBlendData已接入：Idle1_Base→Run_Base使用Run_In，反向使用Idle_In；两段普通攻击分别用Attack1/2_To_Idle、Attack1/2_To_Run收势。入跑被停止时、攻击转跑被停止时都接Idle_In，待机收势期间起跑可由新动作接管。只接当前卡使用的普通攻击和E，不因素材存在而启用Q/W/R。

E正常结束沿现有counter_strike:explode表现事件播放Spell3B：静止选Spell3_B_Idle_anm（1.6秒），移动选Spell3b_run（约1.567秒），对应原版IsMoving条件。它是可打断收势，不创建权威visual_action窗口或施法锁；新移动/停止、攻击、控制、技能和死亡可以接管，已有攻击/受控时不抢播、不排队补播。结束后恢复基础循环。源Run_In、Idle_In及攻击收势按原片播放，没有为缩短表现擅自裁剪；均允许被新动作打断。

实际工作台起手、站立结束、移动结束和移动/攻击打断的画面与日志见[同一交付记录](../../deliveries/2026-10-19_武器大师新卡.md)。
