# Gragas R_End 三维采样适配

输入为本地 Gragas.wad.client 中基础皮肤 R_End 的完整 BIN 树、原始 TEX 和 SCB；来源与转换输出哈希见 source_provenance.json。原始 21 个发射器中 19 个启用，未启用 Distort、SplatterSmall。

制作源工程：`ClashLegends-开发素材库/03-制作中/爆破酒桶/原版独立复现/`。先运行 `build_data.py` 提取源数据，再在 harness 中执行 `node bundle-export.mjs`、`node export.cjs`，最后用 `prepare_godot.py <联调项目路径>` 生成运行资源。源码库只读。

采样使用 LeagueToolkit ltk-manager c06b5bb1dba458a358628b0fd1ddef3a58a4ba43 的解析与模拟，参考其 GPL-3.0 源码；独立预览使用本地 DXBC 经 Hexshade 翻译的原版 shader。Godot 使用本目录单独的 GDScript 播放器和等价字段运算 shader，不调用潘森播放器来播放 End，也不运行浏览器或 LoL 可执行程序。

- sampled.json：120 Hz、259 帧、固定 seed 79；保存三维位置、尺寸、姿态、颜色、双层 UV、颜色查表坐标、侵蚀驱动。各粒子的出生随机性已经采入，同次重播保持相同图案。运行时仍使用三维网格、相机朝向面片和深度交界，非二维录屏或序列帧。
- 顶点行共 38 项：serial；center xyz；size xyz；RGBA；roll；行优先 basis 9 项；基础/第二层 UV 各 7 项（turn/scaleUV/offsetUV/cellUV）；颜色查表 xy；侵蚀 drive。
- 粒子数、出生延迟、寿命、随机乘数、力场与曲线由原始定义驱动采样。floordarlk 延迟 0.3 秒、寿命 1.8 秒，故表现保留 2.15 秒覆盖模拟步长，末帧无活粒子。
- 保留 SCB 顶点 RGBA、背面剔除、地面投影、图集/滚动、双纹理、侵蚀的两段线性羽化、原阈值、普通透明/alpha-add、深度软交界。DistortFAST 的 mode=2 在粒子之前扭曲背景。
- 原始 miscRenderFlags 的 disableZBuffer 位按发射器选择独立 shader：11 层关闭深度测试，8 层保持遮挡。当前 19 层的 depthBias 都为零、flipWinding 均为 false、uvMode 均为默认值、renderPhaseOverride 均为 automatic，不额外套用其他变体。原始地面层排序与 DistortFAST 前置阶段保留。
- 范围适配：原始 GragasR 的 castRadius=350 映射为本项目权威半径 105（直径 210），替换旧经验除数 450；依据当前相机把 XZ 平面映射到权威二维圆，避免俯视投影压缩纵向范围。此投影是 Godot 适配，不伪称原始参数。节点仅作等比单位换算；projection_basis 映射粒子中心，shape_basis 仅对语义上的范围面与底座启用。Sand_Burst、Verticalline 不拉伸本体，Billboard 保持局部尺寸。Ring_ 的圆柱与 mesh 的锥形原始 Y 不因 groundLayer 标记被清零；只有明确地面平面层做贴地处理。高度保持水平单位比例。原始偏心纹理、碎屑和淡出边缘保留，不把每个可见像素当作伤害边界。
- 确认边界：BigLensFlare 的 palette 块没有贴图，仍采用无 palette 变体，原引擎缺省行为未确认。模拟器是复现执行器；120 Hz 固定种子采样不是原引擎随机数实现。Godot 屏幕拷贝包含不透明单位，未单独剔除角色；不宣称逐像素一致。骨骼绑定和场景光照按本次需求排除。

仅表现节点读取权威抵达后的 age；采样结束不触发伤害、位移或网络事件。已在 Compatibility 实际渲染检查，导出预设显式包含 JSON 依赖。

逐层职责与飞行/受击空间分配见 [本卡投影分配](../../../../docs/units/effects/explosive_cask.md#本卡的投影分配)，通用入口见 [投影约定](../../../../docs/reference/SPELL_EFFECT_PROJECTION.md)。
