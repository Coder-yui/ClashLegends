# 潘森模型与特效

2026-09-26使用用户待开发队列的新版“不屈之枪.glb”，最终正式资源source/pantheon.glb。新版坐标已归一化，包装缩放1.05（原1.3，缩小19.23%）；旧版0.015缩放不适用。部件按原版skin0初始列表隐藏Head、Comet、Recall、Joke，保留战斗身体、双臂、头盔、披风、长枪、盾牌。

部署使用Spell4_Hit→Spell4_Hit_ToIdle；短Q使用PantheonQTap原始绑定的Spell1_Hit。动作节点和裁剪见[动画手册](../../../docs/units/animations/pantheon.md)。权威数值不由包装或shader写入。

满怒参考基础皮肤Pantheon_Base_P_enraged的附着网格、Weapon Glow/Streaks及red_pulse；登场保留原版长矛与独立骨骼代理，火光和冲击波恢复为原版七组粒子资源的 Godot 适配。效果为Godot适配，非完整Wwise/VFX引擎复刻。来源包只读，纹理转换ltk-tex-utils，原画不编辑。具体来源及SHA-256见source_manifest.json。

旧模型已放本地开发素材库04-中间产物/潘森重制/20260926，制作源在03-制作中/潘森/remake-20260926。运行目录仅放实际接入资源。

2026-09-26：死亡不再永久隐藏Head；源片第77帧交换HeadHelmet/Head，保留Helmet并按JointSnapEventData对齐C_Helmet_Snap（death_helmet.gd）。未启用的Comet/Recall/Joke保持隐藏。全部已配置战斗动作的子网格事件已核对。

落地特效的当前入口为[素材与接入设计](../../../docs/units/effects/pantheon_arrival_resources.md)。原版转换数据与67项依赖在r_original，Godot播放器、shader及逐层适配配置在arrival；具体坐标、时序和参数只在该设计文档维护。
