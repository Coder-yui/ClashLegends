# 蛮族之王特效

[返回蛮族之王](../tryndamere.md) · [单位索引](../README.md)

无尽怒火使用原版基础皮肤Tryndamere_Base_R_buf_01的身体燃烧与外围旋风：火焰网格、火星、余烬和螺旋网格。按用户要求，仅保留WindTunnel、Temp_Mesh、Temp_Mesh1、sparks、CAS_Flames、FlameBits_Alpha1六个发射器和9项资源依赖；移除地面阴影、光圈、冲击及扭曲。完整原版定义与被移除素材存入本地开发素材库，不再放入运行资源。

身体附着层现分别还原Avatar、Fresnel、Start、End、Fresnel1，不再合并。Avatar使用原色和乘法纹理，侵蚀读取原图Alpha通道；起始闪光0.44秒，结束闪光适配至本项目3.8～4.0秒，持续层原5.3秒适配为4.3秒。结束停止发射，最多0.3秒清理尾迹。

重新读取源模型后，原SKN身高约95.844、源皮肤skinScale=2，项目GLB约0.814678（原模型×0.0085），包装×3.1，因此粒子世界单位换算为0.0085×3.1÷2=0.013175，不再沿用潘森的0.0075。恢复Legacy SpawnShape位置曲线、火焰网格负缩放、UV钳制和粒子轨道速度，保留身体火焰的原始位置与镜像方向。

仍是原版资源的Godot适配；噪声力场和任意颜色查表未完整重现，不宣称逐像素一致。

复用既有原生粒子播放器，新增可选外部定义、圆柱出生形状与屏幕扭曲。未传入这些字段时潘森路径不变。只读权威/快照状态，不参与保命、伤害、怒气、控制或移动；死亡、清场和技能结束释放粒子。

[来源与哈希](../../../assets/effects/tryndamere/native/source_manifest.json)。满怒资源条与技能持续特效独立，只有满怒不会播放大招特效。

研究入口：[原特效作者展示](https://sirhaian.artstation.com/projects/aR81Q2)分别列出R Cast、R Idle、R Cast Resolution；具体层、纹理、位置与时序以本机原BIN/模型为准，网页媒体本轮未能直接核验。
