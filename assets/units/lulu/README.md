# 璐璐模型来源

用户指定源件：`ClashLegends-开发素材库/01-待开发/卡牌模型/仙灵女巫.glb`，接入后原始制作副本迁入`03-制作中/璐璐/`。

正式资源`source/lulu.glb`及Godot导出的同目录纹理为运行依赖，包装缩放0.014。只读核对源库`/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Champions/Lulu.wad.client`中的基础皮肤：skinScale=1.1，没有默认隐藏网格声明；GLB仅一个网格。未改GLB的骨骼、材质或动作。

卡面来自包内`assets/characters/lulu/skins/base/lululoadscreen.tex`，ltk-tex-utils解码原图；主动图标来自`assets/characters/lulu/hud/icons2d/lulu_giantgrowth.dds`，Pillow无重绘解码。图标哈希见`assets/skills/source_manifest.json`。原始提取与转换清单保留在素材库制作中目录。
