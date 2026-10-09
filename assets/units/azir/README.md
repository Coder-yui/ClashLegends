# 沙漠皇帝模型来源

用户指定的待开发沙漠皇帝.glb已移动到开发素材库03-制作中/沙漠皇帝。运行副本位于source/azir.glb，未改动网格、纹理与动画。

包装统一XYZ缩放0.011；源静态网格包围盒约144×278×376，完整轮廓包含长杖与披风，不作为主体大小。仅一个材质，无原生默认隐藏子网格。基础皮肤定义skinScale=0.8为来源参考，项目缩放通过同场比较独立确定。

部署采用原片Respawn（10.5秒）的前6秒，压缩到2秒；只修改卡牌播放映射，GLB保持原样。

普攻节点与片长见[动画说明](../../../docs/units/animations/azir.md)。原版卡面为LCU default-assets2.wad中的assets/characters/azir/skins/base/azirloadscreen.jpg；W图标来自Azir.wad.client的azir_w.dds。哈希见source_manifest.json及技能图标总清单。

渲染验收状态见[本次记录](../../../docs/deliveries/2026-10-09_沙漠皇帝新卡.md)。
