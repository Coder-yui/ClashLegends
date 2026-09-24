# 赛恩模型来源

用户提供：`ClashLegends-开发素材库/01-待开发/卡牌模型/亡灵战神.glb`，原件已迁移至本机制作中赛恩目录。正式模型source/sion.glb保留原模型；source/sion_passive.glb仅从glTF primitives中移除材质名Weapon对应的斧头网格，其他骨骼、纹理和原版动画不变。包装缩放1.4，前向0。

卡面来自本地Sion.wad.client基础皮肤sionloadscreen.tex，ltk-tex-utils解码为PNG。W图标来自同包sion_w1.dds，Pillow解码，不改原画。资源版权归Riot，学习项目使用。动作与观感验证见docs/units/animations/sion.md。

2026-09-23按原版动画表修正：Run常态移动；Passive_Death完整2秒为首次致死等待；狂暴直接使用Passive_Run循环，按用户要求不接Run_In，独立Passive_Dash不接；最终Death截前2.5秒压至0.8秒。包装sion_view.gd按原片第23帧隐藏Weapon，狂暴模型始终无斧。普攻保留完整原片，按攻速等比播放，原版castFrame=11换算为0.36/约0.12秒权威前摇。
