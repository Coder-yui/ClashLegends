# 皇室战争竞技场参考核查

2026-09-12。为新版召唤师峡谷主题 3D 竞技场定向核查；没有修改、解包或迁移外部研究库及 APK。

## 真实本地证据

研究根目录：`/Users/czh/LearningProjects/ClashRoyaleBattleResearch`。

- `reports/apk_entries.txt` 第 7638～7683 行记录 `assets/sc3d/maps/arn_basecamp/`，包含 **7 个 GLB、39 个 KTX**。已进一步只读打开原 APK `/Users/czh/Downloads/nr_15.535.13_release_ff1c6c29.apk`，确认这些文件真实存在，未只依据名称推断。
- 包内模型路径前缀：`assets/sc3d/maps/arn_basecamp/model/`。文件为 `arn_basecamp_rig.glb`、`arn_base_ground_rig.glb`、`arn_base_grass_rig.glb`、`arn_base_wall_rig.glb`、`arn_base_bench_rig.glb`、`arn_rs_base_rig.glb`、`grass_stand_meta.glb`。
- 已检查模型容器：magic 为 `glTF`、版本为 2，但首个数据块是 **`FLA2`，不是标准 glTF 的 JSON 块**；内部还出现 `SC_odin_format`。因此不能把这些文件直接称为已兼容 Blender/Godot 的 GLB，亦未完成它们的渲染验收。研究库目前没有这些模型的标准格式导出或可直接查看的竞技场截图。
- 模型内可读材质引用确实指向战场贴图 `arn_basic_arena_battlefield_diff.ktx`、`_mra.ktx`、`_n.ktx`；围墙模型包含 wood、fabric、fabric_red、tile、gold、roof、roof2、wall 等不同材质引用。此项是文件内容观察，不是截图猜测。

## 构造与布局能提供什么

| 证据 | 可确认内容 | 新版制作中的转译建议（设计推断） |
| --- | --- | --- |
| 7 个分别命名的模型与实际材质引用 | 场地、地面、草、围墙、看台分别组织，围墙采用多种表面材质 | 将对战地面、河岸、桥、森林、遗迹分组制作；避免所有场边物件共用一种轮廓或一种石材 |
| `decoded/assets/locations/training_arena.csv` | 背景引用 `sc/arena_training.sc:training_area_bg`；有 3 类岩石、至少 7 类 cliff、2 类树、2 类灌木、成组树林和前后围栏 | 以少量不同的大地形组组成场边，再在组内加细节，避免等距环形复制树石 |
| `decoded/assets/locations/goblin_arena.csv` | 背景引用 `sc/level_goblin_arena.sc:goblin_bgr`；两侧看台、阵营色遮棚、木塔、水车、不同树石并存 | 保持双边竞技场结构清楚，在四个场边区域安排不同视觉主物；阵营点缀局部集中 |
| 同一 Goblin 布局的坐标 | 看台主要位于 x=-4000/22000；四株河边 bush 位于 x=500/17500、y=14500/17500；水车仅列一处 | 玩法结构可对称，场外叙事装饰可以不完全镜像，降低重复感 |

这些 CSV 是实际资源布局参考，**不是 3D 网格**；Training/Goblin 的 SC 背景与 `arn_basecamp` 的 3D 模型属于不同资源入口，不能混称同一竞技场的完整模型。仅凭 `arn_basecamp` 名称不能确认它对应哪个实机玩法版本；本轮不据此恢复桥尺寸、塔位或地图比例。

## 项目中必须保持的规格

继续以本项目 `scripts/battle/arena_rules.gd` 与本目录 `README.md` 为约束：18×32 格、每格 40px、720×1280 权威战场；河道 y=600～680；双桥中心 x=140/580，通行宽 120px。以上是当前项目规格，**不是本轮从 FLA2 模型测量出的结果**。场边立体地形和桥栏只参与表现。

## 官方交叉参考入口与观察边界

- [Supercell — Clash Royale 官方游戏页](https://supercell.com/en/games/clashroyale/)：官方实机介绍与竞技场图片入口；本轮已读取页面并确认来源。
- [官方页面竞技场介绍配图](https://supercell.com/images/ec0b5871a0476c6ff55c0719fda231d9/bg_intro_clashroyale.ebe0a281.webp)：已从官方页面解析到地址。图片抓取/浏览器加载未成功，**不计为已完成目视参考**。

本轮可靠贡献是原始资源存在性、分层结构及真实布局数据；没有声称恢复并目视验收原版竞技场模型。新版的明亮色调、峡谷树石形状和道路语言应另以 Riot 官方召唤师峡谷图像及可用 LOL 环境素材确定，并在 Godot 实际渲染中验收。
