# 兵线、召唤物与建筑原始动画复核

> 阶段记录，归档于 2026-09-13。下文保留当时的判断和修订过程；当前实现以逐卡定义、卡牌手册及 [开发状态](../../../DEV_PLAN.md) 为准。

2026-09-12。只修改已确认的表现选择及逐片段混合，保留所有生命、伤害、攻速、first_hit、技能与部署/死亡时长。原 WAD 只读，抽取的动画图位于 `/tmp/lol-all-animation-audit/`；逐边原表路径、行号、u64键与时间见 [证据 JSON](animation_building_minion_evidence.json)。高/低32位按源/目标小写FNV-1a32匹配，缺失条目不推断为零混合。

| 卡牌 | 原图 / 原始对象 | 结论与修改 |
| --- | --- | --- |
| 近战兵 | Map11 / SRU_OrderMinionMelee、SRU_ChaosMinionMelee | 两阵营 Attack1/2、Run、Idle1 已对应；仅采纳双方共同的4条零混合死亡入口。保持0.5秒死亡，不强套蓝方独有Attack3B、额外死亡选择。 |
| 远程兵 | Map11 / SRU_OrderMinionRanged、SRU_ChaosMinionRanged | 两阵营当前攻击/移动节点已对应；采纳双方共同4条零混合死亡入口，保持0.5秒。死亡材质/变体条件缺失，不改选择。 |
| 炮车兵 | Map11 / SRU_OrderMinionSiege、SRU_ChaosMinionSiege | 当前 Attack1_BASE/Attack2_BASE 合法；采纳4条共同零混合死亡入口，保持0.5秒。原Selector条件/概率不替换为擅自新增连击。 |
| 超级兵 | Map11 / SRU_OrderMinionSuper、SRU_ChaosMinionSuper | 当前 Attack1/2、Run、Idle1、Death_Base 对应；采纳4条共同零混合死亡入口，保留0.5秒与额外死亡变体选择。 |
| 皮克斯 | Lulu / LuluFaerie | Attack1、Attack2、Crit 都指向同一原文件哈希 460dc3e5211a6b52；Run与Idle1共用29202f431f6c0b83。原图无mBlendDataTable，现有映射保留，不将mCascadeBlendValue=0误当所有边时间；无死亡/部署专用动作，保持已有处理。 |
| 小鬼 | Yorick / YorickGhoulMelee | 修正把 leapWindup 当普攻的问题，使用原 Attack1/2/3，并采用17条当前路径确证混合；保持Run1及0秒部署、0.5秒死亡。声音由jump换为普通cast事件，三段复用同一声音池。 |
| 墓碑 | Yorick / YorickWGhoul | Spawn→Idle1 原表为0，修正部署结束的混合；Idle1/Attack1/Attack2共用文件，召唤仍不伪造攻击。QuickDeath_In→Loop是另一种原生死亡表现，保持项目0.8秒Death，不猜其玩法选择条件。 |
| 尖端炮台 | Heimerdinger / HeimerTBlue、HeimerTYellow | 只采用两种炮台图对当前节点共同明确的3条混合；不凭模型外观确认皮肤/炮台级别。普通攻击和激光当前都已有对应名；统一0.8秒死亡与激光1.6666664秒窗口保持。 |
| 太阳圆盘 | Azir / AzirSunDisc | 原图EnterIdle=Spawn→Idle1_Base→Idle1，Attack1为两套Disk mask攻击50/50选择；Idle1为60/40选择，其中一支为Base→Idle2→Base。现播放器没有相同随机/遮罩轨道，当前基本映射与部署/死亡/idle_cycle保留，不将原随机规则冒充确定循环。 |

## 小鬼的关键资源证据

YorickGhoulMelee原图：Attack1/2/3分别位于L30/L43/L57，均绑定 `Play_sfx_Yorick_YorickQ_GhoulAttack_cast`；Leap位于L77，才绑定jump事件；原leapWindup在L113附近匿名原子节点。用WAD路径哈希提取到临时目录核对：

- `4455bc5b81db1a83` → `assets/characters/yorickghoulmelee/animations/yorick_ghoul_attack1.anm` → Godot Attack1。
- `46136d1767c7fac8` → `.../yorick_ghoul_attack2.anm` → Attack2。
- `663093695ac72e70` → `.../yorick_ghoul_attack3.anm` → Attack3。
- `f78761dd5c123da3` → `.../yorick_ghoul_leapwindup.anm` → 旧配置 Yorick_ghoul_leapWindup_anm。

三段普通攻击在项目中依序选择是表现变体，不宣称恢复原版运行时的选择规则。普通攻击的命中仍由原0.25秒前摇/0.7秒间隔决定；没有增加跳跃位移、伤害段或命中事件。

新的普通cast事件通过已有wwiser TXTP用vgmstream解码；未知Switch固定4030904392=3118032683，保留源-25dB层叠增益。三次离线渲染相同，去重保留一个WAV，不伪称3个随机变体。旧jump文件保留来源归档但不再被当前普攻引用。文件/源TXTP/媒体候选/处理/哈希见小鬼音频manifest；主观听感另行确认。

## 未改的边界

不根据SoundEventData/ParticleEventData帧号直接修改伤害，帧时钟与项目权威秒钟不是同一契约。没有为太阳圆盘增加分层播放器，亦未为minion导入只存在单阵营的动作或猜测状态条件。所有卡均完成原表核对；“保留”表示证据不足或现映射已正确，不能解读为漏审。
