# Sunlit Rift 美术方向

2026-09-12：重做上一版偏暗、树石重复度高的候选竞技场。主题是晴昼召唤师峡谷中的林地遗迹；中央保留皇室战争双路竞技场的清楚结构，场边通过不同的大形和材质层次建立峡谷辨识度。

## 参考与来源

- [Riot — Unleashing the Elements](https://www.leagueoflegends.com/en-us/news/dev/unleashing-the-elements/)及[官方峡谷全图](https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/7b747c9a6331b74a7518c5ea0d8d5e9d81440579-1920x1506.jpg)：道路、河流与森林岩壁的分组关系。
- [Riot 官方海洋峡谷近景](https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/179d06bb848aa022e5d95666a9e1751f4cfc2b53-1918x1167.jpg)：层状灰青岩壁、暖土路、碎石板与水岸植物。海洋主题只作为环境形态参考。
- [Envar — League of Legends: Summoner's Rift](https://www.envarstudio.com/project/league-of-legends-summoners-rift)：手绘 3D 环境资产的风格参考。上述网页图片仅作参考，不作为地图背景或纹理。
- 皇室战争本地研究库与原 APK 提供真实的场地/草/地面/围墙/看台分层，以及 Training/Goblin 场边布局。原版 3D GLB 使用 `FLA2`，尚未转换和渲染；可确认内容与推断边界详见 [royale_reference.md](royale_reference.md)。
- 原版 SR 图集来自本地 LOL `Map11.wad.client`，用于石材、土路和植被/景物表面。来源与哈希见 [source_manifest.json](source_manifest.json)；只读提取、保留原始像素与 alpha，明暗调整在材质中完成。
- 同一 WAD 的 `base.mapgeo` v14 已实际提取 3 种针叶树、苔石、空心倒木和雕刻符文石，共 6 个独立模型；保留原始 UV 分量，树冠与原版树干组合，不导入整张地图地面。精确来源与处理见 [source_props/manifest.json](source_props/manifest.json)。
- 专用手绘草地 `sunlit_grass.png` 由内置 imagegen 生成，替换产生明显草簇重复的原版草地区域平铺；它只作地面材质，不作竞技场背景。生成记录见 [texture_generation.md](texture_generation.md)。

## 新版构图

玩法结构保持对称；原版高树、宽冠树、紧凑树与原创多层树、阔叶树混合，场边采用四组不同的主景，树高、岩层长度、植物密度和空隙分别安排：

| 区域（上方为北） | 主景 |
| --- | --- |
| 西北 | 断裂石拱、散落石块与针叶林 |
| 东北 | 锯齿状层岩、古树与高低变化的林缘 |
| 西南 | 阔叶老树、外露根系和沉入林地的弯曲台阶 |
| 东南 | 三根高低不同的残柱及疏密变化的针叶树 |

两座桥采用有厚度的石桥面、低栏和外侧桥柱，河床下沉，模型侧面保留水流截面。河岸使用间隔分布的大块磨蚀石台、局部芦苇与小型植物。道路是暖土中的不规则碎石残段；塔基周围集中设置破损石环与少量阵营镶边。高物件集中在边缘，水晶轮廓和中央交战区保持开放。

## 色彩与表面

- 草地以明亮黄绿和苔绿为主，远近与区域变化缓慢；土路使用暖褐色。灰青岩壁保留明亮顶面与有颜色的阴影，避免整体压黑。
- 原版针叶树保留原始 UV 和图集形状；原创多层树使用手绘枝叶的多个 UV 区域与 alpha 裁切轮廓。搭配阔叶树、外露根系、苔石、倒木和符文石，增加轮廓与细节变化。
- 河水为清晰的青绿/蓝绿色，辅以克制的岸线亮部和缓慢水纹；蓝红与黄铜点缀集中在基座和少量遗迹。
- 图集含不同物件的 UV 岛，不能整张平铺。专用草地采用不同尺度、旋转角度混合；泥土选取原版图集独立区域；石面在指定区域内镜像采样和三向投射；树枝和原版景物使用明确 UV。采样区域由生成器、`rift_arena.gd` 及 shader 定义。
- 原始图集文件不重绘、不改色；新生成的草地另行存放并记录。当前运行时未必使用 manifest 内全部纹理，实际资产范围以纹理与景物两份 manifest 为准。旧四象限 `assets/archive/2026-09-13/rift_arena/rift_surface_atlas.png` 保留为历史，不再引用。

新版仍是可编辑 `.blend` 与导出 GLB 的候选场景，F5 暂不切换。核心机制回归已全部通过，并完成本机 Godot 四视图及 Blender 源文件实际渲染验收。最终判断依据是 Godot 玩法相机、全景与河岸近景的实际渲染；重点检查明亮程度、局部重复、轮廓遮挡以及原有塔位/桥宽。重建、截图、`--hold` 和 `--inspect` 命令见 [README.md](README.md)。
