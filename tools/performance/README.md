# Mac 性能基准

## 单效果状态覆盖原型

`--family beam`选择本轮16项窄CPU合同；加`--render`只渲染一次蚂蚱R单Quad，沙盾CPU夹具在首帧前已释放，不渲染沙盾。新样本使用正式端点/尺寸，参照为相同正确端点的旧4年龄算法，不与旧亚像素native样本作质量不同的性能比较。资格仅在明确审阅后手工登记，探针不写资格记录。

`python3 tools/performance/effect_coverage_probe.py` 只执行沙盾32项窄CPU合同；显式 `--render` 才运行一次Compatibility实际绘制。固定顺序为新策略一次准备 → 新建正式实例首次消费 → 原7年龄路径 → 新建正式实例；不启动Main/整场、不并行、不自动重试。新路径先行，后续原路径已经受进程/驱动缓存影响，不能把单次数字当冷启动或稳定提速。

沿用safe_probe的20秒/1GiB/30FPS、启动6秒/心跳2秒、ready后增长256MiB、自有进程组清理；叠加整机normal及启动可用估计≥8GiB、运行≥4GiB，每秒检查。允许已有编辑器，拒绝其他Godot游戏；不清理用户进程。结果保存完整源码身份、RSS/保护、分段准备/seek/retain/scan/等待、实际状态和正式消费时间。PNG在计时后写出。使用生产configure/bind_model/advance_status，但无宿主模型、无战斗；不能替代完整实战或全硬件首用验收。契约与未迁移边界见[覆盖说明](../../docs/EFFECT_WARMUP_COVERAGE.md)。

保留资源身份去重的窄合同位于`SpellWarmupSuite.check_retained_identity()`；`retained_resource_check.gd`只执行这个无模型素材的资源图检查，须由现有监督器提供token运行，不调用完整重型套件。覆盖旧新ID顺序、追加统计、晚出现子节点和ImmediateMesh后续surface/material、会话释放；headless不能替代真实预热。2026-10-18第一阶段仅追加一次受保护A渲染，详情和异常证据见同一任务交付记录及素材库`optimization_phase1_retained_identity/`，不自动进入批渲染或重跑对局。

当前先使用下列本地监督入口；本次安全工具改造尚未启动 Godot，Python 假进程回归不代表实际渲染验收。旧无保护基准、160 弹体场景和默认五轮压力配方不自动执行。基准期间保持工作区稳定，并由操作者确认没有另一份引擎或重负载任务；全局锁只覆盖同一 `safe_probe` 入口。

## 有界检查入口

```sh
# 默认只做逐顶点/UV/cache合同，headless；每次创建新证据目录。
python3 tools/performance/safe_probe.py --mode contracts
# 以下分别是明确选择的画面检查，不会顺带跑计时或额外规模。
python3 tools/performance/safe_probe.py --mode capture --total 12
python3 tools/performance/safe_probe.py --mode capture --total 24
# 出生索引低负载CPU/合同；需要画面时显式选择capture。
python3 tools/performance/safe_probe.py --probe particle --mode contracts
```

`--godot` 可指定已有标准版引擎；不安装软件。`--reference` 指向本任务保存的原始脚本，默认在素材库 `04-中间产物/architecture_refactor/batch2b/reference/`。`--output` 必须是新的目录，默认仍在本任务素材库。原始引擎 stdout/stderr 在 `engine.log`，Godot 自身日志在 `godot.log`；`launched.json` 保存实际 argv、PID/PGID，`watchdog.json` 保存停止原因、RSS 与清理证明，`result.json` 另含合同结果和相关组件运行前后 SHA。只比较这些组件身份，不冒充全工作区身份。

本地 Python 包装器在聊天连接之外监督已启动的专属进程组：启动前先验证 RSS 和进程组可见性；监控失败时禁止创建引擎。准备和执行合计最多20秒（`--seconds`只能缩短），首次主线程心跳宽限最多6秒；首次心跳后超过2秒没有递增进度即停止，包括资源准备期间。引擎固定30FPS。RSS按整个拥有组累计，绝对上限1GiB；ready后取3个稳定样本（跨度不超过8MiB或5%），再限制在该基线+256MiB与1GiB的较小值，1秒仍不稳定也停止。这里的RSS不是显存或GPU资源上限。

停止只对创建的 PID=PGID 组发送 TERM，短宽限后 KILL；必须核实该组无活进程才能确认清理（已死zombie除外），不能仅凭leader退出宣称结束。组状态不可读记为未确认，失败/超时保留证据。Python包装器被SIGKILL、系统或驱动失去响应时不能保证恢复；本保护不是GPU内存/OOM根因诊断，也不是继续扩大负载的理由。单个合法准备片段若超过心跳边界，结果就是未验证，不自动延长阈值。

几何场景只支持**全场总量12或24**；五类弹体分配为`[2,4,4,1,1]`或`[4,8,8,2,2]`，其中网格投影重弹体4/8已包含在总数中。爆炸场景也仅12/24个效果。每档仅两对截图：12为team0飞行/team1爆炸，24反向；两档合计四对，保持720×1280和项目9:16窗口。截图按自然帧完成后读取，不用`force_draw`绕开帧率。`--mode timing`是单独的可选入口，仅AB/BA一轮对、每侧每轮默认2样本（1..3），不截图、不逐样本GPU读回；这点样本不足以建立稳定尾分位或整局收益结论。polygon脚本调用不是GPU drawcall。旧`--render/--counts/--rounds`参数在几何脚本中直接拒绝，不能无意重跑旧160场景。

`--probe particle`固定`counts=1,8`、1轮×2样本，支持`contracts/capture`，脚本产物在`probe/`子目录，保持运动/stop/回退/共享索引寿命合同。`effect_dependency_probe.py`默认也改为受监督的headless典型单轮单样本；`--render`才进入同样有界的Compatibility路径。裸GUI探针缺少包装器token会拒绝。这些入口仍需按本次实际改动选跑；历史通过不能替代当前代码的解析、运行或目视确认。

独立调用`run_guarded(command, output, require_heartbeat=False)`仍仅允许显式headless，默认20秒/1GiB。只有显式`verify --guard-profile authority-logic`经审查的三个轻量无表现套件（GrowthSpatialSuite、StructureRewardSuite、AuthorityTimingSuite）使用新增`verification_guard.py`政策：默认20秒（显式超出拒绝）、RSS至多768MiB、正常压力及至少2.5GiB当前可用，保留2GiB；三个内存查询共用0.2秒截止。其他平台拒绝此受保护运行，监控失败不降级。普通verify、导入/数值导出、三进程联网不自动获得新保护或新的限制；正式单局加载仍是下文既有独立政策，未改成轻量预算，也未在本轮重测。采样为轮询目标，不是硬实时承诺。所选引擎身份、小写godot和编辑器共存、心跳年龄及完整边界见[测试手册](../../tests/README.md#查看计划与执行)。

Python安全回归（只启动很小的Python假进程，无Godot/GPU）：`python3 -m unittest tools.tests.test_safe_probe -v`。正常Mac进程可见权限下验证监控预检、并发锁、心跳/墙钟/RSS停止、TERM忽略及残留子进程强杀；沙箱若禁止`ps`，真实探针必须在预检失败处停止。

## 历史基准口径（当前不自动执行）

以下保留已有结果的解释，不能作为当前安全入口或重跑指令。`benchmark.py`、`first_events.gd`和旧重复工作批量入口没有自动获得上述心跳/内存保护；需要另行设计有界片段，不能直接照旧压力参数启动。正式结果仍须记录引擎、组件或工作区身份范围、机器、参数、原日志和实际渲染证据。

- `load`：确定位置、双方桥头拥挤，四分之一寒冰，其余近战兵；高生命、零基础伤害，保持负载。32/64/128 的布局不同，不能只从数量推断线性倍率。
- `burst`：第 60 帧同时生成指定数量纳尔，第 180 帧同时变形，单独记录同步调用耗时。
- `effects`：同 load，并每 120 帧通过真实 `play_card` 预览入口叠加 8 个冻结/治疗区域；绕过经济是压力场景，不代表正常可支付频率。
- `match`：双方每 40 Tick 按固定卡组/位置尝试真实出牌及主动技能，保留经济、手牌、兵线和比赛结束规则。最多 305 秒规则时间；失败/超时不是完整对局。
- Main 初始化后重新设置种子 12345。渲染帧与音频回调仍受操作系统调度，测量并非逐位确定性。
- `--record-audio` 录制 Godot Master 总线到 `master-mix.wav`，有额外开销，单列试听记录，不用于开关性能比较。

预算：当前 Mac 的目标为 60 渲染 FPS（16.67 ms）和 20 Hz 权威模拟（50 ms）。目标是评估阈值，不是已保证每种压力场景达标。默认走菜单的完整加载入口，加载完成后才开始局中统计；保留出牌、召唤及变形的慢帧。load批量生成调用另记，不能用该场景的帧分位数代表部署尖峰。积压含不足一 Tick 的余数，另记最终值。

无界面模式用每帧 0.05 秒推进，只能用于逻辑成本，不能报告为实际 FPS。快照使用真实存活实体完整载荷，测的是构建、序列化、压缩和字节数；不等于网络往返延迟。RSS 每 0.25 秒取样，Godot 静态内存不含全部显存。保留深复制确保表现不拥有权威数据，是否优化由实测支持。

`metrics.json` schema 2 将快照与弹体复制诊断移到主计时循环之后：`snapshot_ms`、`snapshot_bytes`、`particle_copy_ms` 各为最终战场状态的 20 次样本，`diagnostic_policy=20_final_state_samples_after_measurement`。它们不代表整局随 Tick 变化的分布，也不再给 `frame_ms` / `main_process_ms` 额外加入一次快照构建和弹体复制。`tick_ms` 只包围正式 `_sim_step`；`main_process_ms` 包含正式 Main 编排及基准计数开销；实际渲染的 `frame_ms` 包含上一帧主循环、表现、渲染和系统等待。旧 schema 1 的帧数据含每 Tick 额外诊断，不能直接据两种口径宣称游戏性能提升。

## 准备路径与重复测量

`--prepare menu`（默认）调用真实菜单的`_start_local_with_loading`，保留准备就绪和最短展示时间。`--prepare none`显式跳过预建/绘制，只作无预热压力对照。`--entry fresh`为新进程首次进入；`--entry repeat`先在同进程完整加载、退出，再测第二次进入，并记录两次退出后的对象/静态内存。`--repeat 2`每种参数以两个独立进程重复运行。不要混用三类结果。

`--case herald --counts 12`每180帧复现双方先锋各六只召唤，上一批通过真实伤害死亡，保留死亡表现；直接调用权威冲撞命中入口，属于绕过经济的爆发压力，不能冒充正常出牌对局。正常完整对局继续用`--case match --counts 1`。

结果包含加载分段、模型各路径命中/缺货原因/回收/峰值并发与后备初始化耗时、逐帧慢帧索引和生成/变形事件，以及加载后/战斗峰值/退出后的内存和对象数。场景建立中含UI资源加载，resources_usec作为独立累计资源计时与其有重叠，不能直接将所有字段相加。render_usec为实际强制绘制耗时，动画准备与instantiate分别记录；操作系统RSS仍按整个进程取峰值。计数器默认不打印，诊断采样集中在现有性能入口。

图形测量使用当前Godot4.7.1及项目默认gl_compatibility，不降低阴影、分辨率或粒子数量。按[Godot预热说明](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html)，Compatibility仍要求相机内实际绘制；隐藏或仅加载不构成渲染预热。

截图只在计时结束后保存final.png；禁止在采样循环同步写PNG，否则会产生工具自身的慢帧和模拟追赶。结果capture_policy=after_measurement标记修正后的测量，旧第300帧截图数据仅作历史记录，不能据其最大帧判断游戏尖峰。

## 对局加载专项

GDScript 基准可追加 `--perf-deck=id1,id2,...` 与 `--perf-remote-deck=id1,id2,...` 固定双方样本；覆盖只存在于基准子类，在收集资源前应用。未指定时保留固定随机种子的既有样本。`metrics.json` 额外记录双方卡组、完整资源路径/卡牌闭包、模型池容量、加载帧间隔及引擎可报告的显存。基准中的无画面开关仍允许没有模型池。

图形 A/B 应交错顺序、同一设备/卡组/池容量，分别报告新进程和同进程第二局。未清理 OS 文件缓存和驱动缓存时，不能称为冷磁盘/冷着色器测试。不要把 ResourceLoader 总耗时拆成未经测量的磁盘、解码和上传数字。动画轨道快速复制曾因内存增量撤回，现按用户明确接受约78MiB额外静态内存的授权恢复；保留明确别名材质去重及首次冰面预热。历史约30%加载收益不等于当前组合的新测量，过程证据及精确局部回退见加载优化交付。


`tools/performance/first_events.gd` 固定每卡240帧、每帧1/60模拟步长，事件在第0帧部署、第60帧主动及冻结/治疗、第140帧死亡/召唤。记录每帧间隔、事件调用/模拟CPU耗时、前一完成帧的根及3D视口渲染CPU/GPU时间、引擎资源计数、内存、cue与模型池指标。帧间隔包含上一帧事件、表现回调、渲染及系统等待；GPU计时返回0可能表示不支持，不能解释成GPU零耗时；资源计数不是磁盘读取跟踪。高生命、绕过经济及手动先锋命中用于可重复诊断，不是正常对局密度。截图须显式`--capture`，在片段结束后保存。


通过`-- --output=/绝对证据目录 --perf-remote-deck=gnar,anivia,belveth,rift_herald,garen,ashe,freeze,heal`固定对手。cue记录不等于主观试听，也不隔离音频解码耗时。历史加载比较曾采用至少五轮交错A/B；这只是旧结果口径，当前不推荐或自动重跑该负载。保留逐帧时间关联与所有反向指标，不能将零池缺货写成无卡顿。

## 重复工作 CPU 配对测量（历史）

旧入口为 `repeated_work.py --reference ... --output ...`，以下描述已有测量口径，不在当前有界检查中自动调用。

`repeated_work.gd` 在同一当前代码身份上比较四项成本；旧实现只从指定的五份归档源码读取，删除 `class_name` 后作为独立临时脚本编译，不回滚工作区。归档必须包含 `network_snapshot_system.gd`、`network_playback.gd`、`match_card_growth.gd`、`active_skill_roster.gd`、`main.gd`。执行器保存五份 SHA256、当前完整工作区指纹、引擎/CPU/内存、命令、日志及结构化结果，前后指纹变化即无效。输出目录必须尚不存在。

第2A历史负载为32/64/128个存活实体（四分之一寒冰，其余近战兵，双方交替）和六塔，不创建弹体；固定双方八卡，走当前正式资源准备、保留第1批成员闭包与模型库存声明。工具关闭3D创建、声音和自动模拟，显式保存当前资源列表与模型池计划；不测绘制、完整模拟Tick或FPS，不与旧库存口径的局部基准直接比较。该历史批次每项5轮、每轮每侧20个样本，轮序交替AB/BA；记录每样本及每操作耗时、p50/p95/p99、调用数。比较、准备与轮间帧清理不进入计时；计时仍包含两侧相同的循环、回调和结果累计开销，不将这些微基准耗时当作整个生产帧的成本。

- 解码/应用：两个独立真实Main客户端先建立相同实体；预生成相同载荷、递增Tick的包。旧路径为归档的轻量 `packet_tick` 加当前 `decode_validated`/`apply_decoded`（显式复现重复解码），新路径为当前 `decode_validated` 加 `apply_decoded`，两者应用阶段使用相同加强后的静态校验。每包必须成功应用且最终副本等价；不拿同Tick重复拒绝当应用成本。
- 公共采集：归档 `capture` 为每个接收方重采世界，对比一次 `capture_public_frame` 后分别编码；同时测两投影 `[0,1]` 和终局含本地记录的三投影 `[0,1,0]`。金币分别3/8、双方凯隐成长不同；所有压缩输出必须逐包一致，并另查私有字段隔离。明确列出公共采集次数和编码次数；当前公共帧固化成本包含在计时内。
- 成长：每样本连续100次同值输入，旧归档成长所有者复制状态并调用真正 `CardHand._refresh`，新路径调用当前 `Main.apply_growth_snapshot`；计数子类继续执行 `super._refresh`，不以空计数替代UI工作。初次建控件与成长状态在计时外准备；同值刷新次数必须为旧100/新0，另查一次变化仍刷新一次。
- 费用：每样本1000次查询，按全部正式技能、已消费次数及免费再施放组合循环；旧归档 `cost` 的完整技能深复制对比当前纯费用查询。逐组合及累计返回值必须相同，真正施法副本仍由生产 `skill_for_cast` 创建。

队列内存单独测试1/16/64/256份独立解码对象，并持续填充至数量或当前原始序列化字节预算门禁首次拒绝；记录填充峰、丢弃对象释放、drain返回数组仍持有、返回数组释放、再次填充后clear等阶段的Godot静态活跃分配与对象数，并与旧压缩包队列比较。当前16MiB是原始序列化字节累计预算，**不是解码对象堆内存上界**。执行器的进程RSS峰包含这段刻意的队列压力，不代表正常战斗内存；OS/引擎分配器保留内存时RSS也不必随引用释放立即下降。


### 真实队列窗口与独占缓冲回放

```sh
python3 tools/performance/repeated_work.py --network-trace normal --output /新的绝对路径/queue-normal
python3 tools/performance/repeated_work.py --network-trace impaired --output /新的绝对路径/queue-impaired
python3 tools/performance/repeated_work.py --replay-trace /绝对路径/queue-normal/queue-trace/client0.bin --output /新的绝对路径/replay-normal-client0
```

采集复用现有三进程执行器与真实握手/终局断言，仅给测试夹具传入 `CLASH_QUEUE_TRACE_DIR`。不带诊断参数时不安装探针，正式生产类和线上协议不变。`network_queue_probe.gd` 继承生产 `NetworkPlayback`，在真实入队、出队和清空完成后记录队列总数、快照数、raw字节、播放延迟、输入服务器时间和返回序列；原始压缩包在故障延迟之后、进入生产RPC之前与入队对象配对，既不额外解码，也不保存解码副本。`impaired` 保留丢弃三分之一快照和20/120ms交错等待；这段解码前等待只持压缩包，不能算作解码队列驻留。结束时分别保存两个客户端的二进制轨迹与摘要。

摘要给全轨迹及 `snapshot_count>0` 的occupied样本p50/p95/峰值，另列每包压缩/raw大小、实体和弹体数量、入队拒绝和故障主动丢包。**分位数按操作边界采样加权，不是按墙钟时间加权**；峰值包含入队后、同帧出队前的状态。采集会保留压缩归档和操作日志，其运行RSS不代表无探针的游戏内存。

离线回放先调用 `CardDB.all()` 完成77定义的编译冻结，再对本轨迹全部包做两遍完整验证解码并释放引用，随后才取两条队列的测量基线。`decode_warmup` 独立列出定义缓存、首遍及次遍解码的静态内存变化；正常对局在收包前已加载定义，这笔一次性全局缓存不是队列常驻。首次真实回放未预热，当前队列列混入固定1,179,964字节残留，旧路径在其后运行已热；原始结果保留为不可直接比较的首次证据，修正结果使用新的 `warm-final` 目录。

离线回放将相同压缩归档、轨迹与采样数组放在计量基底中，按同一真实顺序重新调用入队、adaptive延迟更新、出队和清空，并逐步核对占用、raw计数和返回事件顺序。旧路径每次 `duplicate()` 后写回同一个字节，强制COW脱离，确保每个入队压缩缓冲独占；内容不变。新路径每次独立验证解码，两个路径分别记录队列静态活跃分配增量、对象增量、occupied分位数、包含ready返回数组仍持有时的峰值、ready释放及clear后的增量；不把采集归档、预加载资源或采样数组算作队列成本。最初64MiB版本的旧辅助列未写入脱离COW，仅是共享压缩缓冲的容器下界，原结果保留，不能与修正后的独占缓冲列混为同口径。

同一离线入口另取轨迹中最大的实际载荷，复制32次、只改服务器Tick，按20Hz到达/60Hz出队分别设1/2/3/4Tick固定窗口。它是受控负载诊断，真实normal/impaired的adaptive轨迹单列；不将合成窗口当公网、任意卡组或最大实体规模保证。固定延迟也可通过测试专用 `--queue-trace-delay-ticks=1..4` 参数指定，普通诊断默认保持adaptive。

当前单包解压上限1MiB。16MiB累计raw预算以200ms最大播放窗口、120ms既有故障注入与50ms一个包为有限边界：`ceil((200+120)/50)+1=8` 个最大合法包，再留8包约400ms余量。raw预算仍不是对象堆上限；trace回放列出8/16/64MiB候选对实际峰值的容纳情况，接近1MiB包的精确边界由网络生命周期回归验证。它不承诺任意主线程停顿或WAN条件，也不把当前样本最大包称为游戏可出现的最大包。

headless/Dummy的正式资源准备使用主线程分批加载，集合/模型池/效果预热保持；可渲染模式仍走原异步。CPU配对双方使用同一当前加载模式，准备在计时外；不得把前后headless准备模式差别称为真实GUI加载提速。`resources_usec`含主线程读取，`threaded_requests`和`threaded_wait_usec`在此模式为0。


## 表现与依赖重复工作

- `projectile_geometry_check.gd`：几何合同与少量Compatibility画面统一通过本页`safe_probe.py`入口；旧大档五轮结果仅保留历史证据，不继续补跑。
- `particle_birth_probe.gd`：保留193帧stop/回退/世界坐标隔离和重复创建释放；当前入口为`safe_probe.py --probe particle`，不再推荐旧32/128实例和7×20配方。
- `effect_dependency_probe.py --output <新证据目录>`：默认受监督headless、典型冰鸟storm、paired、1轮×1样本；明确`--render`才跑Compatibility。压力虚空召唤或cold须单独显式选择，每个引擎进程仍最多20秒，任何失败停止后续步骤。历史5×5数据只按其原身份/负载解释，不是当前默认或整局FPS。首次指引擎首次解析，OS文件缓存可能已暖。

资源依赖发现与源件 SHA 已移到[开发生成与门禁](../../docs/RESOURCE_ARTIFACTS.md)。运行按 provider/variant 小清单加载，不回退源 JSON。旧 `effect_dependency_probe` 依赖历史解析器与旧源布局，只作历史证据，不用于当前阶段验收。当前不再以旧依赖头或旧路径作为运行契约。

Main真实七消费者的共享视图对照与连续跨局窗口诊断保存在本任务素材库，测试用代理仅在工具中使用；正式ProjectileSystem不增加持久统计器。按内容代次共享，不能把同帧更新前后硬合并成一次，也不能把固定帧delta的wall耗时称为游戏FPS。

## 正常单局开局

`python3 tools/performance/match_loading.py --output <素材库内的新目录>` 只运行一个新进程中的真实 Solo/DeckBuilder 确认和开局，不重复进入、不注入压力单位/技能。固定八张玩家卡、AI组牌种子246813579，正常Compatibility/60FPS上限、系统音频、原窗口配置；加载后只取一张自然帧截图。正常资源准备、完整采样年龄/粒子池、模型与声音仍在开战前完成。输出 `loading.json` 分段、路径集合hash、模型各路径预算/库存/CPU与绘制、效果帧等待/覆盖计数，`engine.log` 和 `watchdog.json` 保留退出与保护结果。性能比较须核对卡组、技能、资源路径和层覆盖；不能把30FPS诊断与60FPS正常准备直接相比。

这是独立的单局政策，不放宽上述几何/粒子探针的20秒/1GiB默认值。启动前确认没有其他Godot进程，读取物理内存、内存压力及当前可用比例估计；压力须为normal且估计可用至少8GiB。RSS预算取“当前估计可用减6GiB”和3GiB的较小值，总超时60秒、初始心跳6秒、主线程失去响应2秒；每秒检查系统压力，压力变化或估计可用低于4GiB即停止。仍用独立监督器、同一并发锁和本次拥有进程组清理。压力工具的可用比例不是空闲物理页数，RSS也不包括全部GPU资源；该政策只适用于当前Mac上的有界单场准备，不是产品内存上限或系统失去响应后的保证。监督器默认仍为30FPS，只有此入口显式选择60，其他参数或更高帧率拒绝。

`resource_stage_usec` 是主线程依赖收集加后台加载的墙钟，后台部分含读取、引擎反序列化、任务队列与逐帧轮询，不能全称磁盘IO。`render_usec` 是同步强制绘制调用墙钟，含驱动等待，不是GPU计时器；`frame_wait_usec` 含自然绘制、同步及限帧等待，不能等同CPU忙碌。JSON读取/解析的本次细分来自临时诊断调用，已恢复原玩家源码，测量脚本与恢复映射归档在交付证据内；普通工具不改写正式资源。所有新进程均有引擎缓存首次加载，操作系统文件缓存/Shader驱动缓存未清空；不能称为系统冷启动。


`--profile heavy`选择偏重混合双方卡组，`summon`选择召唤／变形闭包，`diverse`选择多类特效／冰冻；三组固定双方八卡和技能选择，共用`match_loading_plan.gd`的配置。双方主动槽第一张均为镜像，只扩展本方卡牌所选技能。测试子类只固定对手卡组，不改变正式Main。`--inventory --output <素材库内的新目录>`在同一监督器下仅收集这三组定义、合法性、路径、raw文件与模型定义预算，不实例化模型或准备音频，不作为GPU加载性能。正式启动仍每次只选一组，无自动批量或重试。

`progress.json`每约0.5秒保存最后阶段和已完成模型／效果计时；完整`loading.json`、资源审计和战场截图只在完成后保存。保护中止时不得把最后checkpoint当完整耗时。每次前后保存Git可见文件的逐文件SHA256及工具diff，ignored导入缓存不在该身份范围。模型金身预热与效果绘制去重分别计量；可变网格和多遍材质保留全部绘制。2026-10-18三组依赖合法，heavy真实启动触发60秒总时限、未ready；后续两组停止，没有完整三组基线或画面验收，见[本次记录](../../docs/deliveries/2026-10-18_preload_baseline.md)。历史压力warning及初版5.773秒的限制见[旧交付记录](../../docs/deliveries/2026-10-16_match_loading.md)，不能作为本次结果。


虚空召唤离线数据用`python3 tools/maintenance/compact_samples.py --write`生成，`--check`逐位核对并检查确定性；Python3.14标准库Zstandard，无安装步骤。源JSON位于 tools/source_assets/void_summoning/，运行不读取；源身份在开发/构建验证，运行保留维度/长度/载荷SHA及偏移边界验证。`compact_sample_check.gd`是带心跳的CPU全数据等价入口，须由监督器启动，不当作战斗性能。`match_resource_audit.gd`只追踪已知定义/字面量/场景传递路径，并用真实缓存状态确认；不能从preload文本推断全部运行时资源。最终重组记录见交付，普通组旧5.773秒不可当最终值。

单场入口现允许已确认的用户`--editor`进程继续存在并计入系统余量，拒绝其他Godot游戏；不关闭编辑器。`resource-audit.json`的完整来源解析在Main准备计时后执行，外部按钮到报告时间含诊断开销；直接使用`main.total_usec`作开局准备。预热retained只输出类型/配方计数，没有为降低数字删除可变粒子材质。


`--profile heavy --diagnostic`仅用于明确授权的一次A短诊断，禁止与inventory组合。总墙钟收紧为20秒，其余正式单局保护不变；默认关闭的warmup观察回调保留采样和自然draw，内存事件每0.5秒输出`diagnostic-timeline.jsonl`，记录两类帧信号、当前年龄/阶段和只读窗口状态。若draw_wait连续5秒且process仍推进，会记录可区分的信号状态后提前退出；该退出没有ready，不当作加载完成。一次授权不自动运行B/C或失败重试。2026-10-18唯一追加诊断正常完成14.961秒、原等待未复现，根因未证实；实际窗口900×1600，不能与未记录窗口状态的首轮中止算收益。详见本次交付及素材库诊断附录。


`--profile summon --observe`或`--profile diverse --observe`保留同一观测器但使用正式60秒上限，不使用短诊断提前分类退出。每次只运行一个profile，不能与inventory/diagnostic组合；本轮B/C各一次，未自动重试。正式开始前实时保存live-config.json与合法性。2026-10-18最终三组有效样本A/B/C为14.961/8.376/10.051秒；原A首次中止根因仍未知，详见同一交付记录。B最后0.5秒阶段事件尾部未刷新，retain仅能给观察下界；最终loading.json各配方total/frame_wait仍完整，不能补估尾段。


第四阶段模型库存采用[首轮预算、旧储备与构造契约](../../docs/MODEL_POOL_DEMAND.md)。静态inventory输出最终计划数量，不再额外截断；旧32/64只在需求层作为明确保留的有限缓存政策，首轮预算优先，巨大计划在开发门禁拒绝。真实loading报告分列构造声明、首轮来源、旧储备和可耗尽限制。窄入口为`tools/maintenance/model_inventory_revision.py`，默认纯账单，capabilities/scheduler/compile-runtime/runtime分别显式选择；沿用resource_process的20秒/1GiB、pressure/余量/心跳/进程组清理，不自动A/B/C。旧30FPS轨迹暴露帧间隔门槛导致0补货/2次同步缺货。修正按已发生主线程工作有限退让、每帧一步后，仅一次同输入复验得到10命中/0缺货、6个补货、62步最长659μs；不增加初始库存。闲置容量不含活体，不能据静态数量推断局中总内存；有限轨迹不能当整场流畅通过。


### 固定采样层候选

`python3 tools/performance/effect_coverage_probe.py --family sampled` 只执行受保护 headless CPU 合同：11份候选声明、三个机制代表、正式seek与层生命周期、既有primitive/beam小合同。正式provider没有启用新策略。`--render` 会进入真实后端合同及单代表对照；历史真实后端入口曾在材质合同处失败，后续额外复验当时被审批拒绝。用户已追加本任务必要修复后定向再验授权。独立World3D/相机取景修复后两图相同，但每层可见性检查发现flash代表无可辨识像素，最终候选验收失败；所有正式provider仍用旧路径。不得以空白相等放行、扩大范围或放宽阈值。见[覆盖边界](../../docs/EFFECT_WARMUP_COVERAGE.md)。


固定层定向复验入口现限定为`--family sampled --render`→`--targeted`：仅编译azir/cast1两层，逐字段保存工厂→枚举属性→duplicate的类型/精确值；任何不符均在图片流程前停止，全部满足因果链才进入同帧图像和正式新实例首用。该两层已实际完成修复后定向复验：工厂→枚举→duplicate精确链及同帧/正式首用像素全等。诊断现显式分配独立World3D，等自然帧就绪，两层分离取景，并逐层检查非背景像素；最终flash可见性失败（最大面积行落在近黑ramp尾端），不能凭图像相同或旧内层passed放行。取景相机size18只用于分层对照，不改正式root相机/粒子数据。此门槛由effect_coverage_probe.py原有memory_state()→budget(state)调用执行，局部负载仍为20秒/1GiB/30FPS，没有改用A的60秒/3GiB。CPU入口仍检查11份声明/三个机制代表，不调用真实渲染。历史失败、拒绝和资格边界见[第二阶段记录](../../docs/deliveries/2026-10-18_preload_effect_coverage.md)；当前授权及阻塞见[最终收尾](../../docs/deliveries/2026-10-18_preload_mechanism_analysis.md#2026-10-19授权后的最终收尾)。
