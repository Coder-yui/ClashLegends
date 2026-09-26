# 凯隐三形态动画

[普通](../kayn.md) · [蓝凯](../kayn_assassin.md) · [红凯](../kayn_slayer.md)

三个下载GLB的SHA-256完全相同。正式接入仅一份9,887,456字节GLB，106骨骼，三份轻量包装共享网格、纹理和动画源；每实例仅一套骨骼。普通只显示Kayn_Base_Mat（7033三角面），蓝凯显示Assassin主体与头发（6088面），红凯只显示Slayer（7564面）。显隐依据本地LoL基础皮肤BIN初始隐藏列表及两种变形动画的SubmeshVisibility事件。

待机和跑步按三形态选原生片段；普攻轮播Attack1/2/3，死亡Death。Q按Spell1_Dash→Spell1_Stop→Spell1_Circle播放，目标时长0.3/0.1/0.3秒，内部片段零混合；0.5秒的旋转伤害与0.7秒总施法窗口由权威逻辑保持。动画不移动权威实体，也不结算伤害。原始53段筛选21段，加上3段部署裁剪产物共24段，保留形态动作，正式战斗不会由变形动画解锁成长。

实际Compatibility渲染检查过双方三形态、普攻/Q/冻结/死亡与模型展台静帧。普通卡面为原生基础加载图；源库仅找到一张基础加载图，蓝凯与红凯采用相应模型摄影。未将未使用的W/R技能或粒子资源接入。

## Q 结束衔接与工作台

| 形态 | 旋转后移动 | 旋转后待机 |
| --- | --- | --- |
| 普通 | Spell1_Exit_To_Run → Run | 直接混合到 Idle1_Base |
| 蓝凯 | Spell1_Exit_To_Run → Run_Assassin | 直接混合到 Kayn_Idle1_Assassin_anm |
| 红凯 | Spell2_Slayer_Run → Run_Slayer | 直接混合到 Idle1_Slayer |

依据本地 Kayn.wad.client 的 data/characters/kayn/animations/skin0.bin 转场表，64位转场键的高／低32位分别为来源／目标片段名的小写 FNV-1a 哈希。例如 0x6cdfd4792acd4eca 对应 Spell1_Circle→Run，0x6cdfd47937a7d441 对应 Spell1_Circle→Run_Slayer。红凯原表确实复用 W 的转跑片段，并非因文件名猜测。

Q结束不绑定三种 Idle1_In，回待机使用基础姿态混合；部署独立使用下述裁剪片段。转跑只在技能窗口结束后播放，可被新攻击、移动或控制接管，不延长施法锁定。Spell1_Stop 按用户指定作为 Dash 与 Circle 之间的连续停步段。保留的变形动作也仅供观察，局内成长不会让场上旧凯隐变形。

工作台模型目录只保留一个凯隐入口，形态下拉框可直接切换普通、蓝凯、红凯；动作标记、卡面、音频信息随形态更新。实战快捷栏允许分别加入三种形态，按所选形态部署。三形态均为中体型、权威半径18px，共用一份 GLB、四个可切换网格及每实例一套骨骼。

## 地形内移动与 Spell1_Stop 核对

三形态在河道、建筑、塔和水晶占地区域内移动，统一循环播放 Spell3_Run；桥面和普通地面恢复本形态 Run。表现层只查询现有位置与地形几何，不推进入地形状态、不回血，也不改变移动规则；客户端不依赖未同步的本地 inside 标记。地形内 Q 继续播放 Dash/Circle，结束移动走源表 Spell1_Circle→Spell3_Run 对应的 Spell1_Exit_To_Run，随后回到 Spell3_Run。冰冻、死亡和施法动作仍优先于跑步。

Spell1_Stop 原片0.3秒。逐轨道比较确认其首帧与 Spell1_Dash 末帧一致；Spell1_Circle 末帧则与 Spell1_Exit_To_Run 首帧一致。这支持将 Stop 理解为突进停步相关素材，而不是旋转后的固定收招。基础动画 BIN 中它以独立 AtomicClipData 声明，可见出边包括到 Crit 的0.1秒混合、到 Spell3_Run 的 Spell3_Run_In；没有查到自动进入 Stop 的转场记录。另核对 kayn.bin 的 KaynQAbility/KaynQ（mScriptName=KaynQ），仍未提供 Stop 的动态播放条件。**因此 LoL 具体何时调用 Stop 尚未证实，不能据片段名认定每次 Q 都应串入或认定它无用。** 本项目按用户随后明确指定的 Dash→Stop→Circle 接入；保持技能总窗口0.7秒和旋转结算点0.5秒。原表对直接 Dash→Circle 配置0.1秒混合，没有查到 Dash→Stop、Stop→Circle 两条边的显式覆盖；本项目这两条边的零混合依据用户要求和连续素材逐帧验证，不宣称该零值来自原表。

## 镰刀混合修正

复现普通凯隐 Idle→Run 中间帧镰刀甩到头顶，两端姿态却都在身体同侧。Godot骨骼旋转混合使用骨骼Rest作为参考（[混合器实现](https://github.com/godotengine/godot/blob/master/scene/animation/animation_mixer.cpp)、[interpolate_via_rest说明](https://github.com/godotengine/godot/blob/master/scene/resources/animation.h)），不是简单的两端最短路径插值；Root与C_Weapon的本地旋转又分别混合，使参考轴两侧的角度产生可见绕远。

保留原始GLB骨架、绑定与动画，通过凯隐包装的SkeletonModifier3D，仅在真实混合窗口内把已显示武器姿态与目标片段采样姿态在模型空间作最短路径插值。UnitModel3D向包装传递实际选定的混合时长；零混合直接播放源动作，窗口外不改姿势。冻结时不推进，池复用清空上次姿态，不影响身体动作或权威模拟。直接改骨骼层级的试验未采用，原始模型文件保持本轮开始时版本。

验证包括三形态三个待机相位的半程插值、原片采样一致性、冻结、池复用，以及双方待机/移动、攻击出口、地形和Q段间逐帧渲染。观察命令支持 `--locomotion-frames --sequence-frames`。

部署首个动作没有可混合的上一帧姿势：武器在首个混合窗口内直接使用当前片段采样，避免从 Rest 或池中旧姿势额外摆入；之后的动作切换继续使用最短路径混合。

## 一秒部署与展台居中（2026-09-26）

| 形态 | 原片及取段 | 正式部署片段 | 播放时长 |
| --- | --- | --- | --- |
| 普通 | Idle1_In2 全片，约 1.9667 秒 | Deploy_Base | 1 秒 |
| 蓝凯 | Idle1_In_Assassin 的 0–2 秒 | Deploy_Assassin | 1 秒 |
| 红凯 | Idle1_In_Slayer 的 1–3 秒 | Deploy_Slayer | 1 秒 |

在 GLB 中离线裁剪并缩放采样时间，边界补采样；旋转按四元数最短路径插值。三段仍共享原骨骼、网格和纹理，不增加模型实例或运行时裁剪。权威部署窗口仍为 1 秒，原有镰刀混合修正继续生效。

工作台单模型观察忽略隐藏网格，以包装 `get_preview_focus(bounds_center)` 提供的人物脚下原点水平取景，保留包围盒垂直中心和缩放依据。这样不会再被镰刀静态包围盒推向右侧；摄影棚组合取景及战场位置不受该焦点方法影响。

## 红凯跑步进入地形的镰刀方向（2026-09-26）

`Run_Slayer → Spell3_Run` 的两端旋转接近180度，原先模型空间最短弧会扫过红凯躯干。此动作对现在固定沿已验证的身体外侧方向旋转；用 Run_Slayer 0.22秒与 Spell3_Run 首帧建立一次参考旋转轴，随后按该方向选择四元数分支，避免跑步相位变化时长/短弧翻面。只在原有0.1秒混合窗口内调整武器旋转，位置和缩放仍插值，结束准确回到源动作。其余动作保持此前的默认最短路径修正，冻结与池重置继续遵循原行为。

核对用户给出的 [Khada 展台](https://modelviewer.lol/model-viewer?id=141000&lang=zh-CN)公开脚本：普通动作切换在 `playAnimationByIndex` 中使用 Three.js 动作淡出/淡入，默认0.3秒，新动作从起点播放；旋转属性经四元数球面插值，位置等属性线性插值。它按局部骨骼属性混合，与本项目镰刀的模型空间修正不同。所查路径没有身体避障计算，不能据观感认定该站支持自动防穿模。实现证据为[站点当前发布脚本](https://modelviewer.lol/_astro/index.BRxq-oFi.js)，版本随网站更新可能变化。

后续补齐反向 `Spell3_Run → Run_Slayer`：出地形使用相反的参考旋转轴，沿身体外侧返回，仍为0.1秒混合。两个方向各覆盖8个起始相位、冻结保持及末帧回归；渲染工具 `--locomotion-frames` 同时记录进出地形中间帧，`--terrain-exit-phase` 可调整出地形前的动作时间。

## 普攻命中节点与Q旋转结算复核（2026-09-26）

本地 LoL kayn.bin 的 KaynBasicAttack / KaynBasicAttack2 / KaynBasicAttack3 均为 `castFrame=11.5`；三段对应 Attack1/2/3。正式GLB三段均长2.633333秒，即30Hz下79帧时间跨度。动画按当前卡牌攻击间隔完整等比播放，统一前摇按 `攻击间隔 × 11.5 / 79` 映射，不直接沿用LoL的 spellCastTime=0.3161、AttackSlot的0.28秒或此前模板值。

| 形态 | 攻击间隔 | 映射值 | 配置前摇 | 无加成20Hz首个到期Tick |
| --- | --- | --- | --- | --- |
| 普通 | 1.1秒 | 0.16013秒 | 0.16秒（原0.35） | 第4 Tick，0.20秒 |
| 蓝凯 | 0.85秒 | 0.12373秒 | 0.12秒（原0.25） | 第3 Tick，0.15秒 |
| 红凯 | 1.1秒 | 0.16013秒 | 0.16秒（原0.35） | 第4 Tick，0.20秒 |

三种普攻动作采用同一前摇；最大舍入误差为蓝凯3.73毫秒。攻速增益继续通过通用AttackTimeline缩放剩余前摇，表现按相同攻速推进；伤害由20Hz权威模拟结算，音效跟随实际命中。

Q第一段按逐Tick实际扫过路径命中，每敌人一次，不在施法时预结算整条路径。第二段保留本项目0.5秒节点，按当时位置查询圈内敌人；0.45秒尚不伤害，0.5秒结算。Dash/Stop/Circle为0.3/0.1/0.3秒，因此0.5秒位于Circle段内三分之一处，对应原片约0.22222秒（第6.667帧）。

**原版Q第二段精确时刻尚未证实。** Q法术数据有 castFrame=7.5、mCastTime=0.15，但同时 mAnimationName="attack2"，没有把该帧绑定到Spell1_Circle的证据；不能直接把7.5帧当旋转命中帧。动画图的Circle事件只有旋转音效，没有伤害事件；服务端KaynQ脚本不在所查客户端素材中。现有0.5秒是本项目已验证的结算选择，不标注为LoL原版精确节点。GLB时长、映射及源件哈希保存在本地开发素材库 `04-中间产物/凯隐/20260926命中节点/evidence.json`。
