# 剑魔动画

[← 剑魔](../aatrox.md) · [大灭](../aatrox_ultimate.md)

## 动作映射

| 行为 | 动作 |
| --- | --- |
| 部署 / 普通待机 | Respawn / Idle1 |
| 部署后尚未攻击或变形的移动 | Aatrox_sheath_run01_anm（原表Sheathe_Run_Slow） |
| 普通移动 / 下一击被动的待机、移动 | Run_Base / Passive_Idle、Passive_Run |
| 普通攻击循环 | Attack1 → Attack2 → Attack3 → Passive_Attack |
| 二、三刀转跑 | Attack_INTO_Run → Run_Base |
| 被动转待机或移动 | Passive_Attack_out → 对应基础动作 |
| 大灭开启 | Spell4源片段0–1秒 |
| 大灭待机 / 移动 | Aatrox_ULT_Idle_anm / Run_Ult |
| 大灭攻击循环 | Passive_Attack_Ult → Attack1_Ult → Attack2_Ult |
| 收翼 / 死亡 | ULT_out完整片段，0.73秒 / Death前0.8秒 |

攻击或使用大灭后永久退出背剑跑阶段。被动就绪读取权威循环状态，取消前摇不跳段；客户端使用已有攻击、形态序号与就绪快照位。

## 衔接与形态

部署转背剑跑、普通入口/退出、连续攻击的默认混合为0.1秒。LoL原表明确的片段对覆盖默认值：Attack2/3→Attack_INTO_Run为0.03秒、普通跑→Spell4为0、Spell4→Run_Ult为0.25秒。未明确的边界采用0.1秒。原表在制作素材的animation-source/skin0.ritobin；历史对照不代表当前配置。

两形态复用同一模型、骨骼和播放器，靠动作与翅膀显隐转换。普通显示Body/Shoulder/Sword；收翼0至11/32秒显示Wings并隐藏Shoulder，随后恢复普通部件。两个包装场景仅供初次装配与独立预览。Weapon→Weapon_World挂点由包装修饰器处理。

空地属性在转换开始时立即切换，显示高度从当前值渐变到目标。通用空军网格包围盒底部对齐2.3，不扣动画原生离地量。大灭被动为地面动作副本，仅增加0.998591高度轨道，并随动作混合；该值来自普通与大灭待机双脚低点均值之差。普通被动不补高。

动画不驱动伤害、移动、变形寿命或攻击锁；技能时序见单位手册。原版分层加法动画和粒子未全面复刻。
