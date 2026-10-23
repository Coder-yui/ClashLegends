# 沙漠玫瑰模型来源

用户指定源件：`ClashLegends-开发素材库/01-待开发/卡牌模型/沙漠玫瑰.glb`，旧需求中的Clash Legends目录已更名。原文件保持只读；正式GLB只移除基础皮肤默认隐藏的Pistol_Blur、Revolver_Blur、Coin表面，保留原骨架、动画与材质。

包装统一缩放1.2；Pistol_Muzzle创建视觉挂点。死亡4秒压缩到0.8秒。完整映射及源发射节点见[动画页](../../../docs/units/animations/samira.md)。卡面来自同英雄基础皮肤samiraloadscreen.tex，R图标为samirar1.dds，没有重新绘制。

`locomotion.res`为12个姿态片段的独立动画库，保留源上半身遮罩与武器JointSnap组织；包装在准备阶段替换同名片段，不修改原GLB。来源、工具及哈希见`locomotion_manifest.json`。
