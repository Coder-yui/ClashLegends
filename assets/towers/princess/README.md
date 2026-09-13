# 防御塔原版破碎动画

2026-09-13：参考 LoL Turret Skin0 AnimationGraphData 和其关联粒子定义，替换原先倒放重建动画的三段坠毁。

- 原表 Break1 / Break2 / Break3 分别触发显示 Broken1 / Broken2 / Broken3 的独立网格粒子，引用同名 `.anm`。现在导入真实原片为 NativeBreak1/2/3，并按 Break 骨骼组独立播放；新阶段不会抹掉已经在坠落的碎块。
- 塔体 Base → Stage1 → Stage2；死亡立即显示 Rubble，第三组碎块在其上继续播放。项目的三等分血量阈值不变，跨阶段伤害仅触发目标阶段。
- 声音对应原版 Order/Chaos Turret break01、break02、break03；音频和模型读取同一权威阶段，声音不驱动伤害或动画。
- 原始片长约 10、9.9667、11.3333 秒；地面裁切与片尾隐藏由项目负责。原粒子的尘土、透明度曲线等尚未完整移植，不声称完整复刻 LoL 粒子效果。

来源：本机 Map11.wad.client 中 `assets/characters/turret/skins/base/animations/break[123].anm`；原表 `data/characters/turret/animations/skin0.bin`；关联粒子提取文本 `/Users/czh/Tools/lol-asset-tools/turret_native_review/61d12ffa87443d88.rito`。

`tools/assets/import_turret_break_animations.py` 将 lol2gltf 转换后的原动作按骨骼名追加到现有蓝红 GLB，保留原模型、纹理和其他动作。外部原始素材只读提取，未修改。
