# 召唤师峡谷参考与转译

2026-09-05：先前的纯色低多边形森林版本未作为最终方向。根据用户要求，检索并目视研究以下来源后重构。

## 已查阅的参考

1. [Riot Games — Unleashing the Elements](https://www.leagueoflegends.com/en-us/news/dev/unleashing-the-elements/)，2019-12-19。查看文中的峡谷全图与 Ocean Order Full Quadrant 环境近景。官方强调美术不能遮蔽玩法信息。
2. [Riot 官方峡谷全图](https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/7b747c9a6331b74a7518c5ea0d8d5e9d81440579-1920x1506.jpg)。用于理解双基地、道路、河流、岩壁/森林的大形分组；本项目不会移植其三路玩法布局。
3. [Riot 官方海洋峡谷环境近景](https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/179d06bb848aa022e5d95666a9e1751f4cfc2b53-1918x1167.jpg)。用于辨识横向岩层、成簇针叶树、暖土路、碎裂灰青石板与水岸植被。未加入海洋地图的降雨玩法/效果。
4. [Envar Studio — League of Legends: Summoner's Rift](https://www.envarstudio.com/project/league-of-legends-summoners-rift)。参与制作方说明其流程包含概念设计、3D 模型和手绘 3D 资产。

以上仅作研究参考，未将这些图片当作项目纹理或地图资源使用。

## 从参考得出的美术方向

- 道路：暖褐土路中嵌入较宽、边缘不规则的灰青石板，避免均匀的白色方砖；基地用更集中的石板庭院建立文明遗迹感。
- 岩壁：水平延伸的层状大石块、破裂平面、青灰阴影与苔色高光，替换圆滚的碎石围栏。
- 树木：成簇深青针叶树，以手绘针叶和枝梢层次表现体积，避免仅用几个纯色圆锥表达。
- 色彩：深青森林／灰青石材／橄榄绿地被／暖褐道路／克制的阵营蓝红点缀。草地保持连续变化，避免单色绿色地毯。
- 构图：装饰集中在边缘，中央留给对战。峡谷河流的质感压缩到固定两行河道；两座桥和全部权威尺寸仍保持皇室战争规格。
- 3D 边界：手绘贴图只用于几何表面，不把全景图重新铺成背景；模型与 3D 塔共享深度，水纹与材质不参与模拟。

## 原创材质生成记录

`rift_surface_atlas.png` 由内置 imagegen 生成，再存入本目录。它是四象限的草地、岩石、泥土和针叶材质，不是竞技场背景图；运行时由 `ground.gdshader` 和 `surface.gdshader` 读取。完整提示词见 `texture_prompt.txt`。Blender 源文件打包该图用于近似材质预览，最终效果以 Godot 为准。
