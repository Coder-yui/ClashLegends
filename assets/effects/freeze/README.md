# 冰冻 · 冰脉护手与巨魔 W

消费者：`scripts/presentation/freeze_ground_3d.gd` 只读取 SpellSystem 的两个表现窗口，`native_player.gd` 播放原版采样。20Hz 权威控制与区域独立结算，粒子不参与规则。

- 冰冻：Global.wad.client 的 `Items/6662/Particles/6662_Slow_Field`，原版 11 层、14 项依赖。使用原生粒子引擎 120Hz、种子79采样，将原版2秒时间轴映射到3秒冻结；按贴图可见亮边校准，310原始单位映射110px（补偿贴图透明留白）。
- 减速：Trundle.wad.client 中 `Characters/Trundle/Skins/Skin0/Particles/Trundle_Base_W_ground`（源条目哈希 `2cca1ec46346ef82`），原版6层中保留5层、8项运行依赖；按要求去掉Ground_black暗底层。取原版前5秒，按地面可见亮边校准，790原始单位映射137.5px（补偿贴图透明留白），保留原版圆形边缘，不做范围外裁切或额外渐隐；不接入巨魔自身加速或其他技能。
- 两个系统从施放起同时播放；减速场前3秒的内圈按屏幕空间遮罩隐藏，避免透明冰纹和高处冷雾互相穿透。解冻后遮罩撤销，减速场继续2秒。模型仍有正常深度遮挡。原版颜色与层间排序保留，阵营色只加在范围边界。
- `native_particle.gdshaderinc` 基于现有原生粒子采样着色器，增加冰冻遮挡；深度测试保持开启；两套特效仅用缩放匹配作用范围，保留原版边缘与外围粒子。播放器按类型缓存数据、网格、材质，按最大同时可见区域复用槽位。加载预读两个系统的运行资源，并实际绘制起手、延迟出生与持续层。
- `iceborn/source_manifest.json`、`trundle/source_manifest.json` 记录源包、系统、读取器版本和每项资源SHA-256。源件、转换配方与渲染证据位于本地素材库 `05-已完成/冰冻特效重做/`。
- 原来的单张冰纹贴片已被替换。`attached_frost.gdshader` 仍用于建筑模型覆盖，技能图标仍使用冰脉护手装备图标；本次没有修改声音。

[冰冻说明](../../../docs/units/freeze.md)
