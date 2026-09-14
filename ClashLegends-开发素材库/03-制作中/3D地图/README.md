# Sunlit Rift — 晴昼峡谷竞技场

2026-09-12 重制候选：组合原版召唤师峡谷小型模型、原版石材/土路/植被图集、专用手绘草地及重新制作的立体地形，改善上一版偏暗与重复排列的问题。美术方向见 [ART_DIRECTION.md](ART_DIRECTION.md)，皇室战争真实资源核查见 [royale_reference.md](royale_reference.md)。

`rift_arena.tscn` **仍是候选模型**，由独立预览临时加入实际 3D 世界。日常 F5 的 `scenes/main.tscn` 暂不切换背景。2026-09-12 已完成本机 Godot 实际渲染检查与核心机制回归；本次交付为可审阅的新候选版本。

## 规格与坐标

- 窗口 720×1400；权威战场 720×1280，18×32 格，每格 40px；底部 120px 为 UI。
- 河道边界为行坐标 15、17，即 y=600～680；双桥中心 x=140/580，通行宽各 120px，分别覆盖 x=80～200、520～640。
- 公主塔中心为 (140/580, 260/1020)，水晶中心为 (360, 120/1160)。地面、铺路、桥面与基座顶面不高于权威地面；桥栏和桥柱在通行宽度之外。
- 玩法参考相机为 45° 正交、纵向视野 32 单位。Blender 坐标为 `(列-9, (16-行)*sqrt(2), 高度)`；导入 Godot 后为 `(列-9, 高度, (行-16)*sqrt(2))`。水面位于 Godot Y=-0.20。
- 外围岩层、树冠、遗迹及水流只用于表现，没有碰撞、导航区域或战斗对象；不能据模型改动 `radius`、部署范围、塔位或 20Hz 权威模拟。

## 素材与文件

- `source_manifest.json`：原始 WAD、内部路径、解码工具、纹理尺寸和 SHA-256。原版 SR 纹理由 `/Users/czh/Downloads/LOL_Asset_Source/Game/DATA/FINAL/Maps/Shipping/Map11.wad.client` **只读提取**，TEX 解码为 `textures/` 中的 PNG，源档未移动或修改，原始颜色和 alpha 保留。
- 原版纹理是有明确 UV 分区的图集，不能整张平铺。`surface.gdshader` 在指定区域内投射石材；`foliage.gdshader` 读取多层树枝的 UV 和裁切 alpha；`source_painted.gdshader` 保留原版景物模型的 UV 与图集对应关系。亮度、色调与采样范围在材质中调整。
- `textures/sunlit_grass.png`：为解决原版图集草簇平铺后的明显重复，使用内置 imagegen 生成的专用手绘地面。`ground.gdshader` 混合旋转、不同尺度的草地采样，再与原版图集的泥土区域衔接；生成记录见 [texture_generation.md](texture_generation.md)。
- `source_props/`：从原版 `base.mapgeo` v14 中提取的 6 个独立 GLB：`pine_tall`、`pine_broad`、`pine_compact`、`mossy_boulder`、`hollow_log`、`carved_runestone`。保留原始网格分量和 UV；树冠与原版树干组合，并归一化脚底和尺度。未将整张地图或其地面移入项目，来源、分量和哈希见 [source_props/manifest.json](source_props/manifest.json)。
- `source/rift_arena.blend`：保留各物件及 Terrain、Bridges、Woodland、Canopy、Relics 等 Collection，可继续编辑；含参考相机/灯光。`source/.gdignore` 阻止 Godot 自动导入源文件。
- `rift_arena.glb`：按 Collection/材质合批的运行时几何。`rift_arena.gd` 按 `RiftGround`、`RiftWater`、`RiftPine_*`、`RiftRock_*`、`LoLSource_*` 等材质名配置 shader，手工导出须保留这些名字。
- `tools/arena/build_rift_arena.py`：固定种子生成器，不依赖 Blender 插件；重建会覆盖上述 `.blend` 和 `.glb`，手工修改应先另存。`tools/arena/rift_blender_materials.py` 为可编辑源配置原图集选区、树冠 UV 和草地/道路混合节点，并打包纹理。Blender 中的材质为编辑近似，最终动态水纹和世界投射以 Godot 包装场景为准；单独打开 GLB 不会运行 Godot shader。

原版树与原创多层树、阔叶树、断拱和残柱共同组成四组场边景观。选取的图集不等于全部已在运行时使用，实际素材范围见两份 manifest。旧 `assets/archive/2026-09-13/rift_arena/rift_surface_atlas.png` 与 `assets/archive/2026-09-13/rift_arena/texture_prompt.txt` 保留作上一版记录，不再由新版 shader 使用。

## 重建与预览

在项目根目录执行。已有纹理和小型模型时可跳过前两条；重新提取需要 `wadtools`、`ltk-tex-utils`、`lol2gltf` 和含 Pillow 的 Python 环境。专用草地 PNG 保留为生成资产，不由下面的提取命令重新生成：

```sh
python3 tools/arena/prepare_rift_sources.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/arena/extract_rift_source_props.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/arena/build_rift_arena.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
/Applications/Godot.app/Contents/MacOS/python3 tools/dev.py stage --arena --open
```

提取脚本分别生成 `builds/arena_preview/source_texture_contact.jpg` 和 `source_props_contact.png`。v2 预览必须使用图形渲染器，不能加 `--headless`；它实例化实际主场景、六座建筑代理，并通过 `play_card()` 加入双方盖伦与艾希，在 `builds/arena_preview_v2/` 保存：

| 输出 | 检查内容 |
| --- | --- |
| `rift_arena_clean.png` | 玩法相机下的候选地形与六座建筑 |
| `rift_arena_gameplay.png` | 双方单位、桥头及部署提示，包含 UI |
| `rift_arena_overview.png` | 斜视全景、地形厚度与四组场边景观 |
| `rift_arena_river_detail.png` | 河岸、桥梁、草丛和水面细节 |

预览在该实例中替换背景绘制，并配置环境光 0.95、方向光 0.90 与接触阴影；F5 的表现灯光不变。日志输出保存路径及绘制统计。要截图后停留在玩法相机继续观察水纹和表现动画：

```sh
/Applications/Godot.app/Contents/MacOS/python3 tools/dev.py stage --arena --open -- --hold
```

`--hold` 保持手动推进后的比赛暂停，关闭窗口退出。交互式模型检查使用：

```sh
/Applications/Godot.app/Contents/MacOS/python3 tools/dev.py stage --arena --open -- --inspect
```

按 `1` 查看实战正交、`2` 查看全景、`3` 查看河道；全景用左右方向键旋转，滚轮缩放。自由相机下冻结表现代理，返回实战后恢复正常投影。检查器保持暂停的比赛，不是新的游戏模式。

## 本轮验证

- Godot 4.7.1 Compatibility / Apple M5：四张实际渲染图已目视检查，另保存 `rift_arena_inspector.png`。已修复地表规则深斑、过白石材、亮色苔藓圆盘与蜂窝状水纹；双方单位、六座建筑、双桥及部署区域覆盖均显示。
- 三个视角、旋转、缩放经检查器处理函数验证，来回切换后全部单位/建筑代理位置保持一致；日志包含 `RIFT_INSPECTOR_CHECK_OK`，无 `SCRIPT ERROR`。
- Blender 5.2.1 独立加载和实际渲染通过，2,441 个可编辑网格、35 个材质，引用图片无缺失；辅助截图为 `rift_blender_source.png`。
- 最新完整 mechanics 输出 `[机制检查] 全部通过`；本次未修改权威规则、运行时竞技场入口或联网状态。
- 带四级阴影、六座建筑与四名单位的河道检查视图约 465～471 draw calls / 412k primitives；这是独立桌面预览开销，不代表移动端性能认证。正式启用候选前应按目标设备另做性能验收。

后续修改可复验：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/mechanics_check.gd
```
