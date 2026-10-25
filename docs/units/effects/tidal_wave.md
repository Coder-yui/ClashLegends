# 浪潮法术：娜美基础R

[返回浪潮法术](../tidal_wave.md) · [返回总索引](../README.md)

来源为本机只读 `Nami.wad.client` 的 `Characters/Nami/Skins/Skin0/Particles/Nami_Base_R_mis`。保留原水幕网格、泡沫、水雾、两侧水花、涟漪的25层定义，以及纹理、顶点色、UV滚动、混合方式、出生与寿命曲线。采样120Hz、固定种子79，1.4秒时停止发射并保留原版逐层linger规则；项目的命中时钟与这些采样无关。

`miscRenderFlags & 1`逐层映射关闭深度测试着色器，其他层保留遮挡；混合、背面剔除、软粒子与排序沿现有采样播放器实现。源中两个Parent辅助层的子效果概率为0，因此不额外创建独立curl/splash。局部轴转换见[表现时序](../animations/tidal_wave.md)，属于本项目适配，未与LoL客户端逐帧对照。

基础定义声明完整JSON、网格、纹理及着色器预热；加速复用通用Buff表现，无专属目标控制特效。取消包装层统一淡入/淡出；尾部按原始曲线运行到最后粒子消失（生成后约3.42秒），不造成额外命中。bindWeight为0或0.8的粒子按源出生时间与直线路径重建位置，首次渲染晚到或跳帧不改变拖尾位置。来源、SHA-256和加工参数在 `assets/effects/tidal_wave/source_manifest.json`。
