# 奥恩模型与来源

用户提供的完整 GLB 与三张外部纹理保持原样，来源见 [清单](source_manifest.json)。包装场景使用独立网格副本，根据原生 `skin0.bin` 的 `initialSubmeshToHide` 隐藏 Sword、Bucket、Poro 三个材质表面，显示身体、铁砧与锤子。完整打包不意味着所有道具同时显示。

[包装场景](ornn_view.tscn) 模型缩放为1.35，原始身体高度约1.778；已在实际战场与盖伦同镜头校准。此前套用盖伦0.015缩放造成模型极小。权威半径仍为24。原生可见性证据保留在本地 `ClashLegends-开发素材库/04-中间产物/奥恩修复/skin0.ritobin`。
