# 虚空献祭范围

原版 Global 的 Items/223069/Particles/223069_Indicator_On，20层完整采样，120Hz、8秒，种子79。原始源件及重建脚本位于本地素材库03-制作中/虚空召唤；source_manifest.json保留包、BIN与纹理/网格哈希。

player.gd消费权威表现年龄，无战斗写入。地面层遵循源groundLayer；范围以525源单位映射到权威半径160像素，XZ经战场相机逆投影校准。普通alpha和alpha-add沿用共享着色器；Shockwaves1为源blendMode=2，专用反色乘法实现dst*(1-src)，不能替换为alpha混合，否则出现黑色方块。19层关闭深度测试，Groundlights保留深度测试；着色器选择与资源预热共用ParticleRenderPolicy。

原始depthBias与renderPhaseOverride保存在采样元数据；Godot无相同管线阶段，使用排序优先级近似，未宣称跨引擎逐像素一致。到期移除整组；没有删除层、改色或用整体抬高遮盖问题。
