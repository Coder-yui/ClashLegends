# 潘森动画

[返回潘森](../pantheon.md) · [总索引](../README.md)

用户新版“不屈之枪.glb”，包装缩放1.05（原1.3，缩小19.23%，与卡牌大师中体型身高对齐），中体型、权威半径18。全部12个子网格已核对：身体、双臂、披风、长枪、盾牌、Helmet与HeadHelmet为常态；Head在死亡时替换HeadHelmet；Comet、Recall、Joke仅用于当前未启用的原版动作，不在战斗常驻显示。

## 普攻与移动

攻击顺序为 **Attack1 → Attack2 → Attack3 → Attack2** 循环。每次仍是单段连续动作，保留原片前0.9秒战斗段、略去长收势；不在命中处分割动作。攻击间隔0.9秒，统一前摇0.28秒。未满四层红怒时移动使用Run_Base，普攻退出以姿态混合接基础跑步；满四层时接各自Attack1/2/3_To_PassiveRun，第四段复用Attack2的转跑，最后进入Run_Passive。移动中满怒、耗怒或资格清理均按当前资源更新循环。待机Idle1。

命中依据为本地基础皮肤Pantheon.bin的SpellDataResource与30fps动画采样：

| 动作 | 原片长度 | castFrame | 源节点秒数 | 保留片段映射到0.9秒后的节点 | 对共用0.28秒误差 |
| --- | --- | --- | --- | --- | --- |
| Attack1 | 2.6667 | 8.97 | 0.299 | 0.299 | 提前0.019秒 |
| Attack2（含第4次） | 2.6667 | 7.8 | 0.260 | 0.260 | 延后0.020秒 |
| Attack3 | 2.7333 | 7.8 | 0.260 | 0.260 | 延后0.020秒 |

旧说明把Attack1误写成7.8帧，本次纠正。公式为节点÷0.9×0.9。权威20Hz在越过0.28秒的第一个Tick（基础攻速0.30秒）结算；局内攻速同步缩放前摇与整个动作。原数据另有spellCastTime=0.35，不能将它与castFrame当作同一指标。伤害和真实命中音仍由权威模拟派发。

## 短Q

PantheonQTap绑定spell1_hit、spellCastTime=0.25；本地数据没有额外可核实的服务器Q碰撞帧，因此以该施法节点作为短刺对齐依据，不宣称完整复现原版服务器脚本。Spell1_Hit源长0.3667秒，单段缩放到0.4秒：0.25÷0.3667×0.4≈0.2727秒，权威取0.30秒（误差0.0273秒，小于一个Tick）。普通与满怒Q保持同一动作；站立接Spell1_Hit_Toidle，移动按释放后红怒选择：未满层接Spell1_Hit_Torun→Run_Base，满层接Spell1_Hit_To_Passiverun→Run_Passive。短Q长度按当前中体型收至120、宽40。

## 死亡部件

Death源长5.5秒，映射到0.8秒。在原片第77帧（2.5667秒，对应游戏约0.3733秒）隐藏HeadHelmet并显示Head。独立Helmet保留，并按原版JointSnapEventData把C_Helmet对齐C_Helmet_Snap。两个网格版本在准备阶段缓存；逐帧只消费AnimationPlayer播放位置，回收恢复初始头部与挂点状态。骨骼修饰不改变战斗对象。

## 部署

预部署改为1.3秒：0–0.2秒先行长矛从己方侧按当前镜头补偿的斜线落至选定格心，落地后保持斜插，0.2–0.65秒彗星从空中斜落到格心后方3格，0.65–1.3秒贴地滑向长矛。独立Pantheon_Base_Spell4_Slide代理使用原版pantheon_spell4_fly（源0.5秒）和pantheon_spell4_slide（源0.6667秒），分别映射到0.45/0.65秒。代理使用原版星空纹理和橙红色参数，按Godot已转换骨骼坐标校正姿态，蓝红方向镜像；不使用正式英雄模型定格冒充滑行动作。

此前长矛、人物代理、掀土和拖痕只属于特效，没有单位、碰撞、血条或受击实体。权威排程在0.65–1.3秒按滑行冲击波扫掠地面敌人，每目标一次；特效只读取同一轨迹。到长矛处才生成潘森，不重复伤害；实体播放Spell4_Hit（0.3秒）→Spell4_Hit_ToIdle（源1.8秒映射0.7秒）。此时原版Ending_Shockwave从冻结的到点位置向前消散，不跟随单位推挤或转向。共1秒收势，可受伤和被推挤，但不能自主移动、攻击或释放技能。

来源：只读Pantheon.wad.client中的data/characters/pantheon/pantheon.bin、animations/skin0.bin及新版GLB的submeshVisibilityEvents；本地制作源位于开发素材库03-制作中/潘森。
