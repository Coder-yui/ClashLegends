# 金克丝模型来源

用户指定 `ClashLegends-开发素材库/01-待开发/卡牌模型/暴走萝莉.glb`，完成后源件归档至 `ClashLegends-开发素材库/05-已完成/金克丝/源件/暴走萝莉.glb`，正式运行副本为 `source/jinx.glb`；Godot导出的 `jinx_Jinx_Base_Mat.png` 为实际材质依赖。

原模型约0.842×1.935×1.550世界单位，单网格单材质，保留64段动画；包装缩放1.232（在1.12基础上放大10%），脚底约-0.0015无需额外抬升。原skin0没有默认隐藏子网格。共用模型通过火箭炮/机枪动画携持对应武器，原始未持武器保留在身上。包装维护炮口挂点、模型复用、Respawn第25帧挂点切换与Q的原版Minigun骨骼遮罩层。身体切枪片段使用通用变形动作与权威0.37秒切换窗口，详细动作对应见动画手册。

卡面来自Jinx.wad.client的 `assets/characters/jinx/skins/base/jinxloadscreen.tex`，原图解码后接入 `assets/cards/jinx_loading.png`；Q图标来源及哈希在 `assets/skills/source_manifest.json`。原始动画节点、时长与权威映射见 [动画手册](../../../docs/units/animations/jinx.md)。

两种形态共用缩放；枪口骨骼挂点、血条投影随模型适配。罪恶快感包装同步放大1.1倍，弹体备用表现高度40→44；碰撞半径、射程与伤害范围保持玩法定义。

切枪适配：下肢只采样Root/Pelvis及双腿白名单，同相位渐变两种Run并承接循环时钟；不再用骨盆全部后代作下肢遮罩。武器遮罩补充Minigun_Body，完整播放伸缩轨道，结束后持续保持当前形态的枪管及主体尺寸。细节见动画手册。
