# 终极爆弹特效

[返回终极爆弹](../mega_inferno_bomb.md) · [总索引](../README.md)

终极爆弹由炸弹人基础皮肤R改造。来源是只读的`LOL_Asset_Source/Game/DATA/FINAL/Champions/Ziggs.wad.client`，不是根据技能名称挑选几张相似贴图。提取、解码、采样与审计源件位于开发素材库`03-制作中/终极爆弹/`，正式运行依赖位于`assets/effects/mega_inferno_bomb/`。

## 原版资源如何组织

`data/characters/ziggs/ziggs.bin`定义ZiggsR及ZiggsRBoom/ZiggsRBoomLong弹体；`data/characters/ziggs/skins/skin0.bin`的资源解析表把`Ziggs_R_*`键映射到基础皮肤粒子对象，实际对象分布在合并皮肤bin内。不能只搜索单个skin0.bin。

| 对象 | 原始结构与证据 | 项目使用 |
| --- | --- | --- |
| `Ziggs_Base_R_flames_green` / `_red` | 各6个发射器：MaxRange、CenterRange、x1—x4；寿命1.5秒、发射器2秒；资源解析表有对应键 | 己方蓝色、敌方红色落点提示；原生动画时轴适配实际飞行时间 |
| `Ziggs_Base_R_mis` | 5层：Bomb、Buildup、Shockwave、AirHelix_White、cone_add；弹体定义的effectKey为`Ziggs_R_mis` | 飞行炸弹，保留网格、旋转、层级与原始混合模式 |
| `Ziggs_Base_R_Fuse_Trail` | Bomb层的ChildParticleSet明确引用`Ziggs_R_Fuse_Trail`；10层发光、扭曲、火花和明暗拖尾 | 通过Bomb的真实子引用联合模拟，10层整体保留源偏移和出生旋转；不拆分人工挂点。与父系统合成15层missile运行资源，抵达停发、存量粒子自然消散 |
| `Ziggs_Base_R_explosion` | 28层；SoundOnCreate明确为`Play_sfx_Ziggs_ZiggsR_hit` | 权威抵达才切换到爆炸，空放也播放 |
| `Ziggs_Base_R_landingZone_green` | 4层独立蓝青色提示；资源解析表有键，未恢复其准确调用者 | 不与落点flames重复叠加；源件留在素材库 |
| `Ziggs_Base_R_tar` | 5层AcidSplash、Implode、SparksLanding1、shockwaves1、cone_add，无声音；未找到直接命中绑定 | 未擅自接入单目标额外效果 |
| `ZiggsR_flames_red_team` / `_pool` | 解码后是零发射器的空系统 | 不当作额外视觉层接入 |

引线的BombGlow/Glow/Glow1为绑定层，其余拖尾主要为bindWeight=0；最长TrailCenter_Dark寿命2秒。子粒子默认继承规则依据本地转换器的`childBearing.ts`实现核对，未把整个拖尾焊在炸弹当前位置。

## 原版机制证据与项目适配

原始R的MaximumRadius=525、EmpoweredRadius=250、OuterRingModifier=0.65。ZiggsRBoom使用FixedTimeMovement的1.2秒、GravityHeightSolver的4000；ZiggsRBoomLong使用FixedSpeedMovement的2250、重力1300。两者均有60高度偏移、速度朝向以及移动完成后施法/销毁行为。R的施法时间0.375秒，Spell4动画内没有查到粒子或声音帧事件。切换短/长弹道及部分提示/音效的服务器脚本不在已解码数据中，不能宣称已恢复完整原版调度。

项目保留中心80px/600伤害、外圈160px/360伤害、700px/s且至少0.8秒；这些是卡牌数值，不伪称原版参数。整套预警、炸弹、附着特效和爆炸共用一个等比缩放值：项目外圈半径对应原网格纹理的可见圆环亮线（原生半径约476.0616），不再用技能参数525或单独的弹体缩放。原始内外圈birthScale为16.8:8；中心圈基础几何校准为8.4，与项目160:80匹配，之后随整套效果统一缩放。飞行采用抛物线形式，水晶出发高度100px、弧顶项230px为项目适配，原生粒子XYZ等比，不按相机压平。动画、粒子、声音均不能触发伤害。

### 本次重新梳理后的坐标接入

源引用链是`ZiggsRBoom.effectKey → Ziggs_R_mis → Ziggs_Base_R_mis.Bomb.childParticleSetDefinition → Ziggs_R_Fuse_Trail → Ziggs_Base_R_Fuse_Trail`。子引用没有填写boneToSpawnAt、RelativeOffset或ParentInheritanceDefinition；没有“弹身中心”“引线末端”两套挂点。Bomb自身birthScale=23，不作为子系统的额外尺寸倍数。

旧导出流程单独解析两个系统，未解析资源键，Bomb.childSet.children得到null；运行时再手动挂接两个独立播放器，丢失真实的子系统生成和出生旋转语义。当前构建在读取源资源解析表后补齐该引用，交由转换器原有children/childBearing模拟器生成，按source path读取根5层和`0.0`子10层并一次镜像到Godot。旧的两个手工挂点及单独fuse运行目录已移除。源采样中的localOrientation粒子保留各自出生旋转，不能将整组现存粒子每帧刚性转到Bomb的当前旋转。

SCB原文件包含central_point=(0.0148500204, 2.6091001034, -0.0027500391)，旧的ltk_mesh读取器将其读入`_central_point`后丢弃，导出JSON只有顶点/UV/颜色。本次保留该字段，以原文件中心作为项目网格导入坐标基准，在缩放/旋转之前还原局部坐标，再做一次X镜像；没有继续用目测球心或引线末端坐标。这是明确记录的项目坐标适配，不能据此宣称已验证LoL客户端如何使用该字段。

运行时只给联合系统一个共同轨迹与统一缩放。bindWeight=0层保留出生时的世界轨迹变换；抵达时停止新粒子、隐藏Bomb网格，存量粒子按原寿命消散，绑定层的空间位置冻结在抵达姿态。伤害仍由权威抵达事件驱动。

构建与独立核对脚本在素材库`03-制作中/终极爆弹/rebuild_compound.py`、`check_compound.py`；后者核对15层结构、215个BombGlow样本的原生15单位偏移长度及SCB中心字段逐值一致。原始文件和源层级才是依据，历史交付中的手工挂点解释已撤回。

原预警骷髅下巴朝局部-Z；预警整体朝向按施法阵营的半场方向设置，蓝方下巴朝蓝方半场，红方朝红方半场，不根据观看阵营反转。

重伤爱心的叉号采用两片交叉的圆润梭形，端部收窄，灰黑填充及细描边；不使用长方形线段。图标依赖永久状态的快照布尔值，位于基础血条与扩展血条的较右端。部署预览仍显示项目4格外圈与2格中心。当前为源素材结构核对与Godot渲染适配，未与LoL客户端逐帧比对。

最终时序复核：收到抵达事件后，飞行采样时间强制为完整travel，不能再读取可能滞后一帧的progress；停发同时失效帧缓存，确保同一采样帧立即隐藏Bomb。尾迹从抵达时间继续自然消散，预警隐藏与爆炸启动仍以同一权威事件为准。
