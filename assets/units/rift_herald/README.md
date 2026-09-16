# 峡谷先锋运行模型

- 原始输入：项目素材库01-待开发/卡牌模型/rift_herald.glb；正式接入时迁移至本目录source/，没有修改原始GLB。
- 包装缩放：0.9，仅影响表现。权威半径由卡牌定义独立维护。
- LoL原表：素材库03-制作中/峡谷先锋/lol-source/data/characters/sru_riftherald/animations/skin0.ritobin；提取自只读Map11.wad.client，配套source_manifest.json记录源路径与哈希。
- 卡面：模型展台 Idle_Base（先锋）/Idle1（蠕虫），0.2秒，yaw=25，308×560；原包只找到头像图标，未找到对应纵向加载卡面，采用指定模型摄影。
- 双阵营共用材质与包装。[动画与用途](../../../docs/units/animations/rift_herald.md)。
