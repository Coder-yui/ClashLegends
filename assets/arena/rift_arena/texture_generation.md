# Sunlit Rift 草地生成记录

日期：2026-09-12。工具：Codex 内置 imagegen。

输出为 `textures/sunlit_grass.png`，专用于新版候选竞技场的手绘草地表面。原版 SR 图集里的草簇有明显形状，重复采样后形成周期性斑块；本轮单独生成连续草地，保留原版图集用于石材、泥土、树叶和原版景物。

`ground.gdshader` 以两组不同尺度、旋转角度的采样混合该图，并与原版泥土区域衔接；纹理不包含竞技场布局，不作为全景背景使用。原始 LOL 图集没有因此重绘或覆盖。旧 `assets/archive/2026-09-13/rift_arena/rift_surface_atlas.png` 及 `assets/archive/2026-09-13/rift_arena/texture_prompt.txt` 属于上一版历史记录，不再由新版材质引用。

当前文件为 1254×1254 PNG，SHA-256：`99c4e0d84435c4d08829315103d01b4fcfb800701baad0f274e1f53514310da8`。生成结果保留为独立资产，纹理提取脚本不负责重新生成它。

## 完整提示词

```text
Use case: stylized-concept. Asset type: seamless diffuse/albedo grass material for a genuine 3D game terrain, NOT a full scene or a background. Create ONE square seamless tileable hand-painted grass turf texture in the classic League of Legends Summoner's Rift environment art language. Orthographic straight-down flat surface with no perspective whatsoever. Soft painterly jade green, fern green and muted spring olive grass, medium light values suitable for a sunlit daytime map. Lots of tiny sparse tapered brushstrokes indicate blades of grass laid along the ground, gently curved, embedded in quiet broad softly blended color washes. No individual large grass tufts, no bushes, no pine trees, no recognizable repeating motifs, no diamonds, no stones, no paths, no bare earth, no flowers, no symbols, no grid. Absolutely no black patches, no cast shadows, no lighting gradient, no vignette, no rim, no border. Low contrast surface detail with open calm areas that allow champions to read clearly. Painterly authored game material, not photorealistic photograph, not grainy noise. Tile must match seamlessly on all four edges. Fill whole square edge-to-edge with grass color. 2048 square if possible. This will be UV-mapped only onto the flat ground of a new 3D arena; no terrain features baked into it.
```

## 验收状态

已接入草地 shader，并完成 Godot 玩法相机、斜视全景和河道近景目视检查。上一轮的规则深色草簇已消除，连续色调、道路边界及单位可读性已检查。实际渲染命令见 [README.md](README.md)。
