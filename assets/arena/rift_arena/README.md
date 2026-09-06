# Rift Arena — 林间遗迹竞技场

原创手绘风材质与低面数 3D 几何候选场景，主题为“将召唤师峡谷的林地、河道和阵营遗迹压缩进皇室战争双路竞技场”。参考来源及转译依据见 [ART_DIRECTION.md](ART_DIRECTION.md)。不复用旧背景图，不包含来自英雄联盟地图的提取素材。当前游戏仍使用旧 2D 背景；`rift_arena.tscn` 仅作为保留的候选地图与独立斜视预览，不会由 `BattlePresentation3D` 自动加入实战世界。

## 规格与坐标

- 窗口 720×1400；战场 720×1280（18×32 格，每格 40px）；底部 120px 只用于 UI。
- 河道为第 15～17 行，即屏幕 y=600～680。
- 两桥中心 x=140/580，桥面各宽 120px；通行区分别 x=80～200、520～640。
- 公主塔中心：(140/580, 260/1020)；水晶中心：(360, 120/1160)。基座顶面均在权威地面以下，不抬升原有塔模型。
- 保留 45° 正交相机、32 单位纵向视野。Blender 坐标：`(列-9, (16-行)*sqrt(2), 高度)`；glTF 转 Godot 后为 `(列-9, 高度, (行-16)*sqrt(2))`。
- 地面高度为 Godot Y≈0；河水下沉至 -0.23。石桥顶面 Y≈0；栏杆置于 3 格桥宽外。
- 外围高植被仅用于构图，装饰没有碰撞、导航区域或战斗对象。不要据此改变 `radius`、河岸、部署范围或寻路。

## 文件与编辑

- `source/rift_arena.blend`：可继续编辑的 Blender 源文件，地形、桥、铺路、林木、岩壁、符文按 Collection 分类；含与游戏一致的参考相机。
- `source/.gdignore`：禁止 Godot 自动导入 Blender 源文件，运行时仅使用显式导出的 GLB。
- `rift_arena.glb`：按类别/材质合批的运行时几何。
- `rift_arena.gd`：只配置场景材质；`ground.gdshader` 混合草地/土路，`surface.gdshader` 将手绘材质投射到岩石/树冠，`river.gdshader` 提供缓慢水纹。水纹仅用渲染时间。
- `rift_surface_atlas.png`：内置 imagegen 生成的四象限材质图（草地、岩石、泥土、针叶），真正贴在 3D 表面；不是竞技场背景图。
- `tools/arena/build_rift_arena.py`：固定随机种子的完整生成脚本，不依赖 Blender 插件。重新运行会重建 `.blend` 和 `.glb`；手工编辑后应另存源文件，避免被生成脚本覆盖。

从项目根目录重建：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/arena/build_rift_arena.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
```

手工编辑后导出 GLB 时，只选择场景几何，启用 Y Up，不导出参考相机/灯光。保留 `RiverSurface` 与 `Terrain__Living_moss` 节点名称前缀，以及石材/针叶材质名称前缀供材质配置识别。Blender 源文件打包了材质图用于近似预览；最终世界坐标贴图、地表混合与颜色以 Godot 渲染为准。

## 验收

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/mechanics_check.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/capture/capture_rift_arena.gd
```

第二条命令调用实际游戏场景和图形渲染器，截图存入被 Git 忽略的 `builds/arena_preview/`。其中 gameplay 截图验证当前旧 2D 背景与现有六座建筑、双方英雄、桥头交战和部署提示；overview 截图才会额外加载候选 3D 场景用于观察模型结构。斜视角和候选场景加载都不是游戏相机改动。日常 F5 启动 `scenes/main.tscn` 仍使用旧 2D 竞技场。

旧 `assets/arena/arena_rift_v4.png` 留作历史素材，已无运行时背景引用。主机 20Hz 模拟、CardDB、单位/塔权威坐标和客户端快照均未修改。
