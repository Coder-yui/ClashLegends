# 库奇原版R素材适配

来源：只读Corki.wad.client，assets/characters/corki/skins/base/particles/。

- corki_base_r_missile.scb：82顶点、135面，转换为missile_geometry.gd保留逐面顶点/UV；按相机方向投影绘制。
- cork_basei_r_mis.tex / cork_base_r_big_mis.tex：普通/超级导弹UV贴图。
- corki_base_r_tar_shockwave.tex：爆炸冲击环。
- common_flames03.tex：火焰图集，4×4中前三排用于短爆炸，加法混合。

纹理以ltk-tex-utils原色解码。SCB读取格式核对LeagueToolkit的StaticMesh.cs及StaticMeshFace.cs（https://github.com/LeagueToolkit/LeagueToolkit/tree/main/src/LeagueToolkit/Core/Mesh）。制作源、转换记录留在本地素材库库奇目录。仅已使用的网格数据与纹理进入assets。此版本为原版素材适配，未声称完整复刻原游戏全部粒子发射器。

普攻：`corki_base_ba_bullet.png`来自基础皮肤`particles/corki_base_ba_bullet.tex`，使用原版完整亮头/拖尾纹理，以8×48画布尺寸加法混合绘制。源与转换记录位于开发素材库`03-制作中/库奇/弹体音频复核/`。超级导弹爆炸使用独立红色色调，普通爆炸维持金橙色。
