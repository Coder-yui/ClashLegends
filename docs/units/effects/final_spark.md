# 终极闪光特效

[← 终极闪光](../final_spark.md) · [总索引](../README.md)

来自只读Lux.wad.client基础皮肤：Lux_Base_R_cas（9层）、Lux_Base_R_mis_beam（39层）；按用户要求不接入Lux_Base_R_tar受击层。中段R_mis_beam_middle是empty声音承载层，按原事件作为空间音频接入，不伪造可见图形。

120Hz离线采样保留源网格、纹理、出生时序、颜色、旋转、UV、侵蚀、混合和逐层miscRenderFlags深度映射。原生quadType=6光束使用源与目标端点、原生source/targetOffset、scale.x宽度、scale.y/z端点比例及转置UV；各层mBirthTilingSize前两维均非正，对应完整贴图跨度。所有本卡光束mode=0，无分段噪声或距离乘色。

以原版LuxR的TargeterDefinitionLine（3410长、165宽）校准：3410原生长度对应800权威像素，原生指示器宽度对应约38.71像素；项目实际判定独立固定为800×40，XYZ统一缩放，不为54°镜头变形；源地面层Y=-160，整体按原生手部高度160平移以对齐地面，保留层间高度。光晕与边缘折射超出伤害矩形不增加伤害范围。不播放或预加载受击层；不导入英雄骨骼。双方保持原版金色主效果。独立粒子还原不等于LoL客户端逐帧一致，原版实时光照和音频空间处理未复刻。

卡面为内置imagegen生成的独立金白直线光束概念图（308×560），没有照抄R图标；主动技能使用原版被动LuxIlluminatingFraulein图标，来源与哈希见assets/skills/source_manifest.json。源件、脚本与生成提示保存在ClashLegends-开发素材库/05-已完成/终极闪光/源件与过程记录目录。
