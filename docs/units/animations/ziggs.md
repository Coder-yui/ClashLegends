# 爆破鬼才：动画与素材

[返回单位](../ziggs.md) · [返回总索引](../README.md)

使用用户指定的基础皮肤GLB；旧路径中的 `Clash Legends` 已迁移为当前 `ClashLegends`。正式源件位于 `assets/units/ziggs/source/ziggs.glb`，包装场景只做1.4倍等比缩放。源完整静态包围盒约0.907×0.942×1.158；以同场麦林炮手校准稍小体型，不改变权威半径。皮肤没有额外默认隐藏部件配置。

| 场合 | 原始片段 | 项目使用 |
| --- | --- | --- |
| 部署、待机 | Ziggs_Idle1.anm | 通用部署锁后待机 |
| 移动 | Run | 通用移动循环 |
| 普攻 | Attack1、Attack2（均约1秒） | 按顺序轮换，适配1.5秒攻击间隔 |
| 强化投掷 | Spell1（约1秒） | 每次强化出手使用Q动作 |
| 死亡 | Death（约3秒） | 压缩到0.8秒，不延长权威存活 |

源 `ZiggsBasicAttack` 与 `ZiggsBasicAttack2` 的 castFrame 均为10，按30fps为0.3333秒；以1秒导入片段适配1.5秒周期，映射为0.50秒。Q根技能 `ZiggsQ` 的 castFrame 为7.5，源节点0.25秒，映射0.375秒并按配置精度取0.38秒，20Hz在达到阈值的Tick发射。源 spellCastTime 与脚本施法时间不是动画事件，不直接混用。

两套普攻源弹体 `mStartBoneName` 为空，原始高度偏移100；Q子弹体也无专用手骨，源高度偏移60。项目采用身体权威中心作为出生点，视觉起点高28像素并使用抛物弧线，属于项目比例适配，不宣称原版手部挂点一致。模型中的手骨与炸弹骨骼不驱动伤害或落点。

卡面为源 `assets/characters/ziggs/skins/base/ziggsloadscreen.tex`；Q图标为 `assets/characters/ziggs/hud/icons2d/ziggsq.dds`，保留原画。
