# 瑟提原版轰拳

来源：本机只读 `LOL_Asset_Source/Game/DATA/FINAL/Champions/Sett.wad.client`，`data/characters/sett/skins/skin0.bin`。各变体的 `source_manifest.json` 保存源二进制、纹理与网格校验值。

- `full_body`：`Sett_Base_W_Max_Buf_Avatar`，6 个附着网格层。复用正在播放动画的角色 mesh/skin/skeleton；按原贴图、UV、颜色曲线、混合与深度标志叠加，不替换原模型材质。初次满层播放短暂爆闪，稳定段按原 UV 的 5 秒周期循环；不足满层时回收。
- `cast_body`：`Sett_Base_W_Max_Warning_Avatar`，7 个启用附着层（另 2 个源层禁用）。满豪意起手切换到本系统，按动作快照时间单次回放；主体 1.25 秒自然淡出，剩余层在项目 1.4 秒收招结束清理。消耗豪意不提前回收；不与待机身体叠加。
- `warning`：`Sett_Base_W_Shared_Warning_Player`。
- `min` / `max`：`Sett_Base_W_Min_AoE` / `Sett_Base_W_Max_AoE`，包括其嵌套子系统。满豪意共 65 层（28 主层、18 冲击子层、19 头部子层）；`parent1` 的 `Sett_W_Max_AoE_Mis_Head` 定义来自关联 BIN，须跨文件解析，不能保留为空。
- 满豪意修复配方：本地制作目录 `repair_max.py <隔离工程路径>`，输出在 `max-complete/`；对子系统层数和实际采样作断言。来源清单同时保存根 BIN 与关联 BIN 的校验值。
- LoL 定义经 ltk-manager 的模拟器以固定种子 79 采样；运行数据为 60 Hz；预警/冲击最多 3 秒，待机身体为 6 秒循环采样，施法身体为 2 秒采样。子系统从对应 `driver.sources(path)` 读取，不能按重复的 emitter index 读取根粒子池。
- 原版预警纹理中央为等宽直条。源近/远 Z 为 47/779，范围长 732、近宽 316、远宽 776、中央宽 148。`scripts/data/sett_w_geometry.gd` 统一定义源尺寸与 1/4 缩放，卡牌伤害范围为 183/79/194/37；预警、普通与满豪意冲击使用同一原点及等比变换，取消仅预警横向变形。原尺寸对照设置 `native_space = true`。画面只保留原版预警，不增加自绘范围线。
- 原版颜色、纹理、网格、UV、侵蚀与透明混合保留；普通和满豪意独立缓存。发布仅保留运行依赖；制作配方与原始定义在本地素材库 `05-已完成/瑟提特效/`。

表现入口：`scripts/presentation/sett_effect_3d.gd`。警示跟随施法者，冲击由权威伤害 Tick 的可靠固定位置表现事件触发，锁定实际结算位置，残留按原采样自然结束，最多 3 秒。资源预热通过技能 `resource_dependencies` 登记，不由特效结算伤害。

原版还原对照：本地 `05-已完成/瑟提特效/native-reference/harness/` 使用原始 BIN 定义、纹理、网格和本机 ShaderCache 中转换的原始着色器，包含普通 30 层、满豪意 65 层和共用预警 5 层。可用 `npm run dev` 启动，支持暂停、逐时刻观察和单层开关。Godot 原尺寸截图与两队实战截图也在同一目录。

按原定义 `miscRenderFlags & 1` 选择关闭深度测试的 overlay 着色器，避免光层被地面截断；保留源 billboard 朝向，不按名称压平。已移除之前 max Aura 的 0.45 尺寸与 0.55 透明度修饰，普通/满豪意均使用源采样值。地面部分保留共用预警和 AoE 冲击；身体另接满豪意待机及施法附着，不额外接独立挥拳/命中系统。

还原范围：原始资源、父子系统、颜色/尺寸/时序和深度标志；Godot 使用采样回放与移植着色器，屏幕扰动仍使用项目的屏幕采样实现，不声称与 LoL 客户端逐像素一致。
