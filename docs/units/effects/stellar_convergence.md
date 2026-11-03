# 星芒凝汇特效

[← 返回卡牌](../stellar_convergence.md)

源为本地AurelionSol基础皮肤E：AoE_ChildParticle外圈、ExecuteZone_ChildParticle中心及敌方版本；Execute_Minion作为斩杀收束。使用原版网格、纹理、曲线和子粒子采样，5秒停发并保留2秒尾段。各系统XYZ等比缩放，不抵消54°镜头的椭圆投影。

外围主环以网格中线半径377.428对应权威150像素；中心以Ring_Alpha1金色亮线原生半径255.28对应斩杀半径50像素，金色圆内部即中心区域，不再用暗核尺寸校准。友敌依据观察者阵营选择原版颜色。逐层miscRenderFlags通过共享ParticleRenderPolicy选择深度测试/写入；无整组抬高。

制作源件、脚本与原始定义位于本地开发素材库`03-制作中/星芒凝汇/`。卡面由内置imagegen制作，提取黑洞吸引星光的概念重新绘制，并将黑洞主体放在卡面中央；保留主题但不照抄原版E图标；技能小图标直接解码原版E DDS。
