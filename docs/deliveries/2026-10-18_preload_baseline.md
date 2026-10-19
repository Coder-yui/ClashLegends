# 改动记录：三组高预加载压力对阵基线

本页保留本阶段当时的过程、失败和验证身份；五阶段当前状态及待修问题统一见[静态收口审查](2026-10-18_preload_mechanism_analysis.md#2026-10-19静态收口审查当前)。阶段内“尚未开始/无拒绝”等只描述该次执行，不代表后续全任务状态。

## 当前结果

生产基线为 `f4a0fb79a4b47374653aa28a751899f5dba4c1cb`。当前仅实施第一阶段保留资源身份去重，未修改玩法、预热策略、模型容量或绘制策略。后续授权增加默认关闭的warmup观测回调，不是行为优化。三组双方卡组经当前真实 collector 检查均合法且无依赖错误。

最终已取得A/B/C各一个有效新进程样本：确认到加载完成14.961094／8.375645／10.050514秒。A为另行授权的20秒短诊断，B/C按原60秒保护正式测量；均ready、退出0、清理和前后身份确认，三张真实战场PNG已读取像素。原A首轮60秒中止完整保留，等待未复现，根因未知；不能据失败到成功宣称优化收益。三组数字为优化前基线；随后授权的第一阶段单次A为14.259358秒，retain观测21.958ms。第一阶段已复核保留，额外材质已由私有随机生成池差异解释；未进入批渲染／共享。第二阶段仅做一次虚空召唤CPU局部采样，第三阶段只读审查模型动画；均未再改生产实现。本次有限优化已收束，全部改动在工作区，未提交推送。

## 2026-10-18：测量适配与有界启动

- 测量工具：三组固定 profile 共用双方卡组／技能配置，保留 FixedOpponentMain；增加监督下仅依赖盘点入口、路径 hash、当前中文名和 Git 可见文件逐文件身份。完成计时截点移到最终审计之前；完成后留 0.8 秒采集 ready RSS，暂停战斗。现有总时限、心跳、压力、RSS 和排他锁未放宽。
- 三组静态规模（闭包卡／资源路径／定义模型路径／定义目标容量／效果请求）：A 25／863／27／184／44；B 31／600／34／318／22（唯一配方19）；C 19／716／20／112／40。附属场景也进池，A 实测全池31路径、192目标容量、145初始实例，不能把定义预算冒充整个池。
- A 已完成分段：scene 0.114725s、plan 0.023556s、resource_stage 2.330400s、audio 0.002247s、model_pool 3.149605s、ground 0.011920s。父子时间不重复相加。最后checkpoint为确认后57.771619s；模型和地面之后的效果阶段已观察至少52.117s，尚未完成，不能写成成功加载耗时。
- A 模型计数：121次draw，27次凝滞状态样本。最慢已完成模型项为剑魔终极433.414ms、普通397.688ms、凯隐基础335.917ms；draw墙钟不是纯GPU时间。效果只记录腕豪full_body setup=6.950ms，无完整配方total/draw/frame_wait，原因仍待定位。
- 环境：Apple M5／16GiB，macOS26.6.2，Godot4.7.1，Compatibility/OpenGL4.1 Metal；配置720×1280，60FPS上限。实际窗口尺寸最终记录未生成。新进程、OS/驱动缓存可能热；一次中止不是均值或最坏上界，未拿历史15.034/9.211秒计算收益。
- 保护：运行内存压力始终normal；RSS峰值1.204GiB。60.1875s含监督器清理；`total_wall_timeout`，PID=PGID=57195，TERM后无活成员。后检normal、可用估计9.12GiB，仅原编辑器保留。未关闭用户应用或修改系统设置。
- 身份：运行前后6921个Git可见文件SHA一致，包含卡定义、collector、manifest、provider、项目和测量配置；ignored `.godot`导入缓存未逐文件核验。inventory后仅修正完成计时截点，A使用的精确工具diff/hash单独保留。
- 验证：`verify --plan`选出工具Python检查与审计；预算单测5项、轻量Python假进程看门狗20项通过，项目审计77卡／0错误，`git diff --check`通过。仅依赖inventory通过不代表GPU加载完成；未运行全量或追加对局。
- 证据目录（本机ignored）：`ClashLegends-开发素材库/04-中间产物/preload_baseline_20261018/`。内含短报告、summary、三组inventory、A的preflight/progress/最终heartbeat/watchdog/原始日志、前后逐文件身份、精确工具diff/source、postflight及验证日志。中止使loading.json、最终resource-audit和battle.png未生成，未补造。
- 遗留：B/C未启动；A完整耗时、Main total、效果配方排行／层数／retained资源、ready RSS、真实画面仍缺失。若继续，应先补当前配方／年龄／draw进入退出与完成帧信号的低频诊断及中间审计，再决定有界验证；本次未进行该诊断或生产修复。
- 交付：本机报告和完整证据ZIP已生成并通过ZIP校验；Library辅助程序在tools/list连接阶段失败（TLS），未开始上传，没有已确认附件ID，原文件保留。

### 同任务只读复核

- 未新增引擎或测试。两份原引擎日志未见SCRIPT ERROR/ERROR或契约失败；腕豪full_body走通用10年龄采样，setup后经seek/retain/资源扫描/自然frame_post_draw等待。现有progress仅含timings，无法定位第几个样本或排除协程中断；未认定正常重渲染或GPU瓶颈。近期六提交未改动warmup/腕豪播放器，夹具已使用runtime接口，未发现确定的回调丢失点。源码、迁移diff、原始字段与最小诊断建议收入证据目录readonly_review/，生产未修改。
- Library原辅助程序再次重试：已越过TLS连接，但返回`Library prepare_uploads is not available`，未开始写入；无附件ID，未改用其他传输路线。

### 同任务授权：一次低频插桩短诊断

- 用户明确授权后，仅A追加一次新进程观察；预算从60秒收紧为20秒，压力/RSS/心跳/排他不变，未启动B/C或自动重试。normal与余量预检后启动，正常完成；没有实施优化。
- warmup新增默认关闭的Callable观测：当前配方、年龄、seek/retain/资源扫描/draw_wait前后阶段；新工具在内存中计process_frame与frame_post_draw，0.5秒批量保存事件和对象/窗口状态。无需改变自然绘制、采样顺序或次数。测量精确差异、代码及前后SHA保存diagnostic_A_once/，运行前后6923文件一致。
- 原超时未复现、根因未证实。confirm_to_loaded=14.961094s、Main total=14.934773s；effects=9.147911s、model_pool=3.331304s、resource_stage=2.287739s。44配方完成，226效果draw／234去重跳过，setup不与配方总耗时重复加。效果frame_wait合计6.439741s，不称纯GPU；单次最大观测等待约335ms。首次中止不能据此计算改善百分比。
- 新有效热点：虚空召唤zone=1.026616s（setup0.547932s）、凝滞0.763515s、格温mist0.622830s、龙王wave0.577173s。保留资源检查阶段累计约0.751317s，其中wave0.225721s；优先建议身份集合辅助去重，但未改实现。虚空召唤已经用CLPS，后续先拆SHA/解压/材质成本，不重复建议已做的紧凑化。模型动画和draw等待分别列候选与风险，详见素材库诊断附录。
- 27快照／3490阶段事件／0丢弃；最后351 process、475 post_draw（包含模型强制绘制），所有配方返回。observer6.047ms、最后快照之前的快照累计12.299ms，其他观测开销未完全隔离；插桩与缓存/窗口差异使本次成功不能视为修复。无SCRIPT ERROR或契约错误，退出有19 ObjectDB实例泄漏警告，归属未定位。
- 实际窗口900×1600，可见、未最小化；原A无窗口状态记录。battle.png实际像素已查看，地图、塔/水晶与手牌有效，非完整动画/音频/联网验收。ready_seen与完成结果成立；RSS峰值1.766GiB，后检normal、自有组清理确认。辅助JSON的diagnostic loading_completed字段原无条件false是工具标签错误，保留原始文件并在运行后修正包装器，不重跑。
- 新增检查仅verify --plan、Python语法和diff检查、单次真实诊断及图像读取；没有全量或额外引擎测试。Library仍在prepare_uploads能力发现处失败，未写入、无ID。新工具/观测/文档均未提交推送。

### 同任务授权：补齐B/C各一次正式样本

- 先只读复核A标签：原JSON loading_completed=false保留，ready_seen、heartbeat ready、完整loading、有效PNG、退出0一致；旧新diff只在run_guarded之后改报告标签，计时和保护不受影响。保存BC_formal_once/A-label-audit.json与A-label-only.diff，不重跑A。
- 增加--observe正式观测入口，不启用A短诊断的20秒/提前分类退出；B/C均沿用原60秒、3GiB/动态余量、normal压力、6秒/2秒心跳、ready增长256MiB、60FPS与排他。helper与warmup观测实现同A；唯一计时前新增实时MatchSession合法性检查。生产collector、manifest/provider及卡定义身份未变，复用原errors=[]清单。B/C固定文件身份完全一致；每组运行前后SHA一致。
- B有效：confirm8.375645s、Main total8.342663s、scene0.102424s、plan0.004770s、resource1.700714s、audio0.002597s、model3.922542s、ground0.011941s、effects2.574406s；padding0，opponent_wait1us。实际池36路径／249实例／322容量，19唯一配方、84效果draw、81既有去重跳过；效果等待2.312244s。RSS1.548813GiB，ready/cleanup/identity均通过。退出有17 ObjectDB实例警告。
- B后检normal、可用9.28GiB、仅编辑器，才启动C。C有效：confirm10.050514s、Main total10.019985s、scene0.095084s、plan0.034393s、resource1.622438s、audio0.001589s、model2.598336s、ground0.772361s、effects4.866550s；padding0，opponent_wait1us。池28路径／76实例／128容量，40配方、170draw／175既有去重跳过；效果等待3.709617s。RSS2.002457GiB，ready/cleanup/identity均通过；退出10 ObjectDB实例警告，后检normal、仅编辑器。
- 三组实际窗口均900×1600、可见未最小化，未人为改焦点/窗口；全部为新进程，OS/驱动缓存可能热。仅各一有效样本，不是均值或最坏上界。B/C未失败或重试；原A首次失败不计入成功基线、不删证据。
- B最终19配方计时完整，但最后快照只含14配方完成事件，尾部5配方阶段事件未落盘；retain观察仅≥12.437ms，不拿它与A751.317ms/C405.093ms作完整比较。未补造或追加运行。
- 只读检查ObjectDB警告：表现退出已调用pool.release_sources并free离树样本，不能直接归咎样本忘记释放；无verbose类型/ID，RefCounted/Callable图、诊断监听或其他离树对象只列候选，不实施修复或为警告重跑。
- 最终报告更新为素材库三组预加载基线报告.md；three-group-summary.json和精简原始字段审阅.json包含时间层级、配置、每组原始字段、Top模型/配方、内存、监督退出和完整路径。按收益证据与风险排序的方案全部未实施。Library仍不可用且无写入，不再重复尝试或绕传输路线。

### 同任务授权：第一阶段身份集合去重（已复核保留）

- 仅改保留操作：以本场实例ID字典代替Array线性成员查询；Array保留首见顺序与强引用，每age递归节点／扫描可变资源／draw判断不变，不按路径合并。表现退出显式释放两容器。没有跨配方批渲染、模型共享或Fast切换。
- 新窄合同对同一Resource图逐项比较冻结旧算法与新算法的ID顺序、追加ID/类型，覆盖重复age、同空路径不同实例、晚出现节点/材质/纹理/网格、ImmediateMesh后续surface/material替换、会话释放与强引用生命周期；最终六快照一致。只运行该轻量方法，未执行重型SpellWarmupSuite全体。
- 夹具异常完整保留：WeakRef类型推断解析失败、20秒保护清理后修正；首次五阶段通过。补充surface用例后局部/WeakRef临时引用导致释放断言，隔离到独立函数帧后六阶段通过，未改生产释放逻辑。最终轻量检查passed、清理和身份确认；没有借失败抬阈值。
- 唯一一次正式A：confirm14.961094→14.259358s，effects9.147911→8.407903s；_sample retain观测751.317→21.958ms，wave225.721→4.287ms。_view retain不在该独立计时中。effects帧等待6.439741→6.675817s；单样本缓存/调度差异未隔离，不把全部总差归为稳定收益。
- 路径hash、计划、规格、初始池145/192、全部采样层、44配方、逐配方draw、226draw/234跳过一致。保留资源5048→5049，绘制资源键4783→4784；只差远程虚空鱼spawn多1 ShaderMaterial。其私有rng.randomize是只读定位强候选，具体种子未记录，不能声称统计完全一致。未改随机策略或追加A，待复核。
- RSS峰值1.765884→1.845588GiB（+81.14MiB），Godot静态当前约+0.48MiB；不同口径，不解释为已证明的字典独占成本。原全套保护不变、normal，A ready/cleanup/identity通过，退出0，实际PNG已查看。仍有19 ObjectDB实例警告；原52秒等待未复现根因未知。
- 测量工具仅在计时截点后刷新最后事件并记录index大小，精确diff/source/hash另存；A后只增强测试，生产代码SHA保持不变。产物在同一素材库optimization_phase1_retained_identity/，第一阶段结果.md和phase1-comparison.json可直接核查。Library不再重试。本阶段完成后停下，等待复核再决定下一阶段；未commit/push。

### 同任务授权：第二阶段虚空召唤setup定位（未改生产实现）

- 第一阶段只读复核补齐：retained无外部赋值、别名修改或绕过helper写入；voidfish_ranged私有rng.randomize生成的spawn池由5变6，与独立可见资源扫描及多1材质一致，未重跑。K=2设计审查发现屏幕/深度采样、同中心遮挡、动态ImmediateMesh和共享ground槽位等上下文约束，本阶段不实施双世界或合帧框架。
- 唯一一次局部样本仅创建一个headless播放器，调用load_kind及setup_native(0.01)，不模拟对局、不执行后续age/draw、不展开巨大JSON。计时只加在ignored源码副本；去掉计时行并还原一个preload路径，两个文件均逐字节还原当前生产源码。源文件86,756,851字节、CLPS10,522,326字节、解压载荷134,420,536字节；完整源SHA、载荷SHA、维度及偏移检查均保留。

| 局部CPU段 | 毫秒 |
| --- | ---: |
| setup合计（以下为子段，不重复加总） | 807.255 |
| 播放器new及入树 | 0.008 |
| load_kind/prewarm | 807.220 |
| └ 紧凑读取合计 | 778.069 |
| 　 打开/头解析/头校验 | 2.254 |
| 　 源文件SHA256 | 274.071 |
| 　 压缩数据读取 | 1.152 |
| 　 ZSTD解压 | 38.970 |
| 　 载荷长度及SHA256校验 | 425.861 |
| 　 offsets/IDs/values数组构造 | 0.016 / 0.553 / 34.356 |
| 　 偏移检查及data赋值 | 0.805 |
| 　 压缩/载荷缓冲释放 | 0.002 / 0.001 |
| └ 五种几何模板准备 | 2.935 |
| └ 二十个发射器材质模板准备 | 26.187 |
| setup_native（缓存检查/池槽/seek0/其他） | 0.027（0.001 / 0.009 / 0.015 / 0.002） |

- SHA两段共699.932ms，约占本局部样本86.7%，分别验证不同对象且各执行一次；不能删除其中之一、按mtime复用、跳过checksum或引入无失效依据的摘要缓存。第二次prewarm已直接命中原缓存，仅1us；几何已按路径去重为5份，20个材质模板保留各发射器参数。数组构造可见临时复制，但目前未证明现有API下有保持表示/完整校验的低风险消除方式，未为约34.9ms引入格式或缓存层变化。
- 初始seek(0)没有粒子实例；后续age才出现的粒子节点及实例材质不在本setup计时内。播放器Script首次load/编译在计时外；headless缺少实际相机/GPU，材质准备不是纯GPU时间，也不能把这里807.255ms与整场A的550.891ms直接比较或外推整场收益。计时/字典插桩本身有开销（紧凑读取子段合计778.041ms，父段另含28us）；每种仅一个样本，指纹读取也可能预热OS文件页。
- 监督器沿用已有safe_probe.run_guarded/默认Limits：20秒、1GiB、30FPS、首次6秒/后续2秒主线程心跳、ready增长256MiB；额外沿用正式整机normal且启动可用≥8GiB、运行可用≥4GiB、拒绝非editor Godot的门槛。正式预检normal、可用9.28GiB，仅原editor；1.365551s完成、RSS采样峰值517.047MiB、Godot静态当前157.588MiB/静态峰值406.660MiB，二者均不称VRAM。ready/清理确认/逐文件身份通过，退出0、errors=[]、日志无ERROR或ObjectDB警告；后检normal、可用9.28GiB，仅原editor。未触发保护、未重试或放宽预算。
- 仅运行verify --plan审阅潜在改动范围、Python语法/插桩逆变换检查、本次局部采样与diff检查；未运行计划列出的14领域套件，因为对应生产文件最终未改。未再跑A/B/C、未测渲染或首用、不打包大证据、不重试Library、未提交推送。证据为素材库同任务目录optimization_phase2_void_setup/：measurement-only.diff、source-identity.json、measured-sources、single-local-sample内setup/result/watchdog/heartbeat/完整日志/前后逐文件身份。本阶段结束，等待复核，不继续其他热点。

### 同任务授权：第三阶段模型动画有限审查（保留现状，任务收束）

- 复核当前代码及原计时，无新Godot进程、采样或测试对局。16份目标源码/场景/GLB/现有测试与第一阶段A运行后的指纹一致。已有优化包括：本局_wrapper_templates按导入Mesh合并剑魔普通/终极的派生网格与高度轨道库；copy_track替代纯数值动画的通用深复制；同库动画别名只复制一次；无脚本模型筛选声明动作及RESET，脚本包装保守保留全库；准备元数据随池对象移交，领取时不再绑定复制。没有重复实现这些已有优化。
- 确认一条候选重复链：剑魔_ready先执行prepare_visual_animations，将只读高度模板复制成每实例动画库；池入树后ModelVisualResources.bind_model又复制一次。首次模板构建和包装器首次复制计入instantiate_usec；之后显式prepare_visual_animations已因_full_mesh返回，prepare_wrapper_usec仅约11–13us不能用于否认首次成本。第二次bind计时同时含材质/网格收集/覆盖准备，不能全部宣称为可省动画时间。

| 第一阶段A原始模型计时（ms） | 普通（4实例/容量4） | 终极（4实例/容量4） |
| --- | ---: | ---: |
| 模型路径total | 406.163 | 433.778 |
| instantiate（含_ready） | 123.931 | 158.109 |
| animation（显式包装准备及bind） | 133.231 | 134.385 |
| sample_prepare | 67.968 | 65.315 |

- 上表为已经取得的同一个A样本，路径total含子段，不重复相加；纯动画分类扫描、copy_track、包装器首次复制尚未分别计时。GLB静态清单有97个原始动画、32154个channel；导入后的实际轨道/片段以引擎为准，不能把原始channel数当运行时复制计数。

| 共享对象/状态 | 当前可变性与所有权结论 |
| --- | --- |
| PackedScene、导入Mesh、Shader、Texture、原材质 | 按只读约定复用；Mesh/Material本身仍是可变Resource。剑魔换形只换各MeshInstance.mesh引用，不改共享几何或材质参数；隐身/覆盖使用本实例副本。 |
| _wrapper_templates字典、normal/wing Mesh、高度AnimationLibrary | 本局持有，构造完成后只读，不是引擎强制冻结；两种场景引用同一GLB。高度轨道及Passive_Attack_Ult只在模板构建时派生；模板不能直接作为可变活体动画。release_sources清空本局模板字典，节点仍按自身强引用持有在用资源。 |
| 每实例AnimationLibrary/Animation | 包装器复制后，通用bind再复制；同一库内原有别名保留，实例之间不共享可变动画。运行代理会写loop_mode，回收按本owner保存的_loops恢复；资源值/事件/压缩轨道/脚本/元数据保留深复制后备。 |
| AnimationPlayer、播放section、speed、混合及Skeleton姿态 | 每节点独立，禁止跨单位复用。weapon_snap只读本播放器片段名，写本Skeleton骨骼；不同单位可处于攻击、死亡、冻结等不同状态。 |
| ultimate_form、网格选择、UnitModel3D动作/死亡状态 | 每wrapper/代理独立；原位换形只保留本单位模型。死亡代理拒绝晚到换形，释放时移交本单位owner/player。 |
| 闪白/冰冻/凝滞/强化/隐身材质与参数 | owner或实例持有；同owner内部明确别名可以复用，不扩成跨单位共享。回收恢复覆盖、loop、section、骨骼、变换与初始形态；不共享Unit代理、源信号或附属效果。 |

- 不直接删任一层复制：cover_studio/capture_cover_combat有不经过通用bind而直接操作包装器播放器的路径；通用bind也服务无包装模型、分步补充、缺货与死亡后续模型。当前没有“包装器已拥有独立库、仅移交一次”的正式所有权契约。仅按英雄、方法存在或一个prepared标志跳过复制，不能证明别名、原模板、loop及生命周期隔离。本轮未改源码，也不引入只读分类缓存：源Animation并非强制不可变，缓存失效依据与收益未测。
- 窄合同仅审阅现有实现及测试覆盖，不称本轮运行通过：PresentationSuite._check_animation_copy覆盖数值轨道全部存储属性、marker、loop/关键帧隔离、资源值深复制、同库别名及筛选/RESET；LoadingAssetsSuite覆盖两个普通剑魔的网格共享、独立播放器/动画和高度轨道写入隔离；DeckBuilderSuite有回收与初始形态恢复，TimedFormCycleSuite有原位换形，AnimationStateSuite有死亡覆盖冻结/晚到换形。它们尚未证明“移除第二次复制”的新协议，也不是本轮新运行结果。
- 如以后单独验证上述候选，假设应限定为“池路径两次完整复制中的一次可通过显式所有权移交消除”。最小方式是一进程、同一pool下普通/终极各一个节点，分开计_ready/template/copy、bind分类/copy_track/材质，核对所有活体Animation与模板身份、同库别名、单实例loop/关键帧写入、不同播放/形态/死亡与回收对另一实例无影响，并覆盖不经bind的独立包装入口。使用既有headless局部20秒/1GiB/30FPS及normal≥8GiB启动、运行≥4GiB、6秒/2秒心跳等保护；超限停止，不扩副本、预算或转整场。本轮未启动此计划，不承诺能省上表某一整段。
- 本轮正式变动仅本记录；verify --plan仅文档、无领域套件，差异/链接/指纹检查通过。审阅定位证据和本阶段文档完整diff在素材库同任务optimization_phase3_animation_review/。无新大包/Library上传、提交或推送。

### 本次优化收束状态

| 状态 | 范围与证据 |
| --- | --- |
| 已实现并复核保留 | 第一阶段实例ID集合辅助保留资源去重；原Array强引用/顺序、后续资源发现与实际draw保留。 |
| 已验证 | 三组各一个有效实际加载基线；第一阶段六快照窄合同和仅一次A；第二阶段一次受保护CPU局部拆分。第一阶段A总耗时差−0.701736s、retain观察差−729.359ms均为单样本观察，不是稳定承诺；三组原加载退出仍有19/17/10个ObjectDB警告。 |
| 本次不建议实施 | 跨配方K=2/双世界框架；删SHA、mtime/无失效缓存；共享活体Animation、播放器、姿态或材质参数；为了优化减少库存、采样、质量或推迟首用准备。 |
| 未验证/未解决 | 动画两次复制消除的所有权协议与收益；原A首次60秒中止、效果等待至少52秒的原因；ObjectDB警告归属、跨设备/冷驱动/重复样本统计、完整首用渲染/音频/联网。第二阶段headless CPU与第三阶段既有分段不能累计为整场收益。Library原路线不可用且无附件ID，未绕行重传。 |

本次到此收束，保留现有工作区供审阅；未自动启动其他热点、整场A/B/C或全量验证。
