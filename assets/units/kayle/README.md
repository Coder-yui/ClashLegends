# 正义天使

共用source/kayle.glb，来自用户下载“正义天使.glb”；“正义天使 (1).glb”拥有相同网格、部件和动作，网格未重复接入，只提取其进阶身体贴图exalted_body.png供16级使用。选用模型已从待开发经制作中移动至source/kayle.glb；另一份在本地开发素材库03-制作中/正义天使/models保留为进阶贴图源件。用户给出的带尾空格名称在磁盘上实际为不带尾空格的名称。

melee_view与ranged_view只过滤网格，部件依据Kayle.wad.client的Skin0初始隐藏表和动画Evolve3/IdlePassive。模型池恢复由共用池恢复网格及骨骼，包装没有游戏状态。

source/wing_16_gradient.png来自原版kayle_base_wing_16_gradient.tex，exalted_wings使用其第一行金白色带；简化呈现静态16级翅膀色彩，不声称完整复刻原版着色器。卡面由Riot Data Dragon原版Kayle_0.jpg获取，无裁绘，路径与哈希见source_manifest.json。

技能W图标来自本地kayle_w.dds，经Pillow无重绘解码，登记在assets/skills/source_manifest.json。原始包只读，所有转换、音频匹配和验收产物位于本地开发素材库。

满层被动参考 Skin0 `Kayle_Wings_inst` 的 `KayleEnrage` 动态材质。原版 `Kayle_Base_P_Enrage_Buff` 粒子定义无发射器；因此采用附着羽毛的材质变化，不添加无来源的身体光环。原版 Rage_Gradient_Texture 与 Mask_Texture 分别为 `kayle_base_wing_rage_gradient.tex` 与 `particles/kayle_base_fire_tile.tex`，本项目无重绘解码为 source/enrage_rage_gradient.png 与 source/enrage_fire_tile.png。

两形态在真实命中攻速被动满4层时渐入（0.5秒），刷新不重播，到期或死亡渐出（0.5秒）。参考原版UV缩放(2,2)及滚动速度(-0.4,0.25)，按兼容渲染限制亮度，保留羽毛纹理与轮廓。近战使用独立表面颜色层，远程直接混入现有16级材质以避免透明多遍排序覆盖；这属于Godot适配，不是LoL着色器的逐指令复刻。模型包装只接收UnitModel3D传入的满层布尔状态与表现时间；每实例材质独立，回池清零。新增专属快照布尔状态，不能用最终攻速推测满层。
