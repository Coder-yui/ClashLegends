# 开局预加载机制审查：全牌库账单与删减方案

## 2026-10-19：授权后的最终收尾

本节为当前总状态，下文保留各阶段原始事实。用户明确授权继续收尾，并新增沙皇 `azir/cast1` 两层一次定向真实复验；此前审批拒绝已成为历史，不再作为当前缺少授权的理由。当前阻塞是实际系统内存门槛，未放宽或绕过。

| 范围 | 当前已落地与可复用证据 | 当前未完成或明确保留 |
| --- | --- | --- |
| 清单与增量生成 | 77定义/43provider/90variant；90清单、12模型、74投影、1CLPS；最终Python-only check 0错误；compiler输入闭包及失败传播已修 | F5/F6人工按钮、完整发布PCK未验；大源重新编码在现worker预算下未证明 |
| 效果覆盖 | 沙盾独立/附属及蚂蚱R beam已启用，独立资格仍2份 | 4provider/11variant/72层候选仍未启用；view/ground等继续旧路径；674CPU和4Python不替代真实渲染 |
| 模型与材质 | 12模板、同根一次动画所有权、match可达材质预建；复用既有同身份合同/有限画面对照 | 潘森14像素差异候选已撤回，维持旧实现；legacy、动态粒子与miss仍有运行成本 |
| 库存与补货 | 初始A/B/C=108/195/52（旧145/249/76）；闲置容量162/286/84；44step-bind/23loading-only；30FPS饥饿已修 | 首轮事件加旧有限储备，不是数学最小；活跃+闲置可超过capacity；唯一真实轨迹10hit/0miss/6refill不证明所有场景 |
| 最终真实验收 | 已核对旧日志；未发现当前实现的正式A结果；未发现旧测试残留，只有用户编辑器PID6389 | 原heavy配置一次A入口在引擎启动前被内存保护阻止；沙皇定向复验同门槛未启动；当前总加载/RSS/首用收益仍未知 |
| 整理与同步 | 当前规范/阶段记录已核对；资源check、审计、diff及范围/凭据检查完成；提交状态见本节后续 | 原素材、失败日志/截图、证据和.godot全部保留；没有完整发布、全量回归或额外压力测试 |

### 实际执行与保护停止

正式入口为 `python3 tools/performance/match_loading.py --profile heavy --observe --output <证据>/A-once`，复用既有双方卡组及选择，没有手造A。保持900×1600既有窗口、60FPS，60秒、RSS `min(3GiB, available-6GiB)`、启动正常压力/可用≥8GiB、运行≥4GiB、6/2秒心跳和ready增长256MiB。入口在 `budget()` 报 `Insufficient normal-pressure system headroom before launch`；未创建测试引擎、未进入计时，因此没有新的总耗时、分段、RSS、draw、ready或battle.png，不能写作通过或性能退步。

紧随停止的只读查询为物理16GiB、pressure_level=2、available=33%（5,669,356,830字节，约5.28GiB）。沙皇原20秒/1GiB/30FPS及相同系统门槛也未满足，故未调用渲染入口。其factory→enumerated→duplicate字典、同帧图片和正式首用均没有新结果。**这是保护前置阻塞，不是本轮自动审批拒绝、运行中或结果不明**。两项额度均未消耗为真实运行；须在同一门槛恢复后按原范围执行，不扩大到其他家族/全库。

旧A14.961094秒、retain-only A1 14.259358秒仅为各自旧实现的单次缓存样本，不作当前优化收益。沙皇即使后续单变体通过，也不能批准全部4provider/11variant/72层。

本次只复用未变实现的历史定向合同，不累加各阶段断言或把自动宽计划全跑。已查看当前 `verify --plan`，其共享入口导致范围过宽；文档显式计划仅audit/diff、无引擎。当前 `resources --check` 0错误；项目audit为77卡/7173文件/0错误；`git diff --check`通过。初始444路径（暂存空）逐文件SHA/大小清单及高置信私钥/常见GitHub、AWS、OpenAI凭据形式扫描0命中；不是穷尽秘密证明。大文件仅既有CLPS及原SHA不变的迁移JSON，不包含本地素材证据。

### 分批提交与格式检查边界

前两批已提交：`d1560802`（生产代码、生成门禁/产物/配方及回归；414原路径，Git因源JSON完整重命名报告413项）与 `1b6374ee`（12个独立诊断入口文件）。第三批为当前文档及交付状态，最终SHA和实际远端核对结果在最终回复及本地 `commits.json`/`remote-sync.json` 留证，避免把计划push写成成功。

暂存检查首次将未跟踪新文件纳入后，发现两条 `new blank line at EOF`：`scripts/presentation/model_visual_template.gd:6`、`tools/maintenance/effect_manifest_builder.gd:66`。上文普通 `git diff --check` 当时只覆盖已跟踪差异，不能当作所有新文件格式全绿。两文件的原字节均为已验证产物producer输入，删除空行会使收据失效并要求受保护生成；当前系统门槛不满足，因此**保留两条无运行影响的格式警告**，没有手改收据或降低检查规则。第二批暂存检查通过；第三批另检查。第一批所有路径已用 `--no-renames` 与预审414路径完整核对，确认源JSON仅移动、无丢失或额外文件。

证据在本机ignored目录 `ClashLegends-开发素材库/04-中间产物/构建与验证/preload-final-closeout/`：`workspace-review.json`、`verify-plan.json`、`preflight-stop.json`。本轮未创建测试引擎，不需要杀进程；没有关闭用户应用。清理仅核对无残留；没有可确认应删的本轮临时文件，删除数0，未按体积清理素材/缓存/证据。


### 工具导航授权状态补正

后续只读复核确认工具README末尾仍保留“未获执行批准”的旧状态，现仅修正当前导航：用户已经授权一次沙皇cast1两层真实复验，阻塞为既有系统门槛。历史阶段的审批拒绝记录不改。沙皇包装器原已导入memory_state/budget并在启动前调用，门槛并非本轮新增；本轮没有实际调用它的preflight。A实际执行到budget拒绝；其preflight.json在budget之后写，因此A-once也没有独立preflight.json或guard结果。两项均无新引擎/渲染结果。

本补正只改工具导航及本记录；按文档范围检查，不启动测试/测量/生成。两条producer末尾空行仍保留，避免在禁止生成时使现有产物身份失效。补充只读git状态另发现18个未跟踪.gd.uid伴随文件，在原干净状态核对后出现；全部保留且不纳入本次文档提交，不推断创建者。最终工作区状态以最新实际git输出为准，前述干净状态仅对应原三提交收尾时点。


### 用户关闭应用后的原门槛复核与UID收尾

用户随后表示已关闭能关闭的无关应用，授权自行解决中间问题并继续原范围。文档补正已先提交推送为3a818f5ff9b14fc4387a71ce7332bbe5297f6a76；本轮不重跑任何已完成测量，不扩大验收规模或改变保护。

先只读核查仍只有用户Godot编辑器PID6389，无match_loading/effect_coverage_probe/resource_process测试残留或可确认自有可回收进程。02:22:28 UTC读取pressure=2、available=36%（约5.76GiB）；02:25:52.428529至02:25:52.434906 UTC的实际保存样本为pressure=2、available=34%、5,841,155,522字节（约5.44GiB），调用原budget(state)仍明确拒绝。此次不是调用A/沙皇入口后的新失败进程，没有消耗两项真实运行额度。带原始vm_stat、swap及进程列表的证据为本机preload-final-closeout/resume-preflight/system-preflight.json与processes.txt。

可用量实现核对：[Apple memory_pressure](https://github.com/apple-oss-distributions/system_cmds/blob/main/memory_pressure/memory_pressure.c)的get_percent_free调用memorystatus_get_level；[XNU vm_pressure_response](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/vm/vm_pageout.c)由available page count/total pages计算整数百分比。项目用physical_bytes×percent//100转为估计，不是vm_stat的纯free页或精确可分配承诺；整数百分比有量化误差，不能解释距8GiB的数GiB缺口。独立pressure=2也已不满足原必须等于1的条件。当前VM统计显示大量压缩与交换：首个诊断样本压缩器413611×16384字节（约6.31GiB），swap used 5890.88MiB（约5.75GiB）；这是系统状态，不证明某个应用泄漏或内存一定不可恢复。没有证据将现公式判为错误，故未修改memory_state/budget、未降门槛、未purge系统缓存/改OS/关闭用户应用。

18个新UID逐项确认：均为本批d1560802/1b6374ee新增脚本的.gd.uid伴随文件；每份一行合法uid://标识，对应源存在，仓库UID无重复/冲突。沿用已有Godot脚本伴随文件版本管理方式纳入提交，不将可复现身份当临时缓存删除。完整清单及源新增提交、SHA在resume-preflight/uid-review.json。UID不改变资源生成器输入中的GDScript内容，未触发重生成；两条producer空行警告继续保留，不为风格改动重新生成。

本轮只补UID与本文、工具导航的状态说明，按文档/伴随元数据范围审计；当前A整局加载与沙皇真实材质链/同帧画面/首用依然未验收，已授权但被原系统条件阻塞。尚无安全的自有资源可清理来解除条件，不能把完成提交与完整性能目标混为完成。

## 2026-10-19：静态收口审查（当前）

后续已按授权修复本节三处发现，通过窄合同并完成两个沙盾辅助pin续记与增量生成，当前资源门禁0错误，见[集成修订](#2026-10-19三处集成修订当前)。本节的“本轮仅改文档/check0错误”限定静态审查当次，不描述后续修订。

本节跟进已授权五阶段实施，正文其余部分保留最初分析时的事实。HEAD仍为`f4a0fb79a4b47374653aa28a751899f5dba4c1cb`；本轮仅改文档并做静态审查，未启动Godot/渲染/生成链，未commit/push，未删除源件、证据或缓存。没有将历史断言相加作为当前工作区验收。

### 完成状态与证据边界

| 范围 | 实际状态 | 尚缺或保留 |
| --- | --- | --- |
| 阶段1：清单与增量生成 | 已实现；77定义/43provider/90variant；90清单、12模型、74投影、1CLPS共177份记录；本轮Python-only check为0错误 | 下述模型producer闭包缺口已修并完成必要生成；完整源在新worker预算内重新编码未证明，成功增量复用旧CLPS；F5/F6人工按钮及完整发布PCK未验 |
| 阶段2：状态覆盖 | 沙盾独立/附属各一次及malzbeam已启用，独立资格仍仅2份 | view/ground及其余动态家族仍旧路径；现有身份去重不能称为显式状态覆盖完成 |
| sampled静态层 | 4provider/11variant/72层为候选，正式provider无fixed_sampled_layers标记 | 原真实材质签名失败；默认值修订只有CPU证据，azir/cast1两层真实复验当时denied、未执行；新增授权及当前系统门槛阻塞见上节 |
| 阶段3：模型/动画/材质 | 多数确定性加工前移，12模板；同根一次动画所有权；match预建可达材质、工具显式tool模式 | Pantheon候选14像素失败已回退；其他legacy包装仍可能加工/复制，动态粒子和库存miss仍分配；有限代表画面不是全动作/整场验收 |
| 阶段4：库存与补货 | A/B/C静态初始108/195/52（旧145/249/76），闲置容量162/286/84；44step-bind/23loading-only；正常30FPS不再永久跳过 | 数量为首轮事件+旧有限储备，不是数学最小上界；活跃+闲置可超过capacity；唯一真实小Runtime为10hit/0miss/6refill/62步最长659μs，不证明长期吞吐/全路径流畅 |
| 阶段5：收尾 | 本轮静态审查、文档导航和工作区清单完成 | 下述生产问题已窄修、产物恢复一致；最终同条件加载/RSS/首用对照、清理实际执行、分批提交及远端同步均未完成 |

阶段细节见[清单生成](2026-10-18_preload_resource_artifacts.md)、[效果](2026-10-18_preload_effect_coverage.md)、[模型](2026-10-18_preload_model_ownership.md)、[库存](2026-10-18_preload_model_inventory.md)。基线记录只作为旧比较端；不能把各局部毫秒相加推算整场收益。Standard选择保持，不切Fast。

### 可复核的实质发现（静态审查当时，后续已修）

1. **模型增量构建漏编译器输入（P2）**：[resource_build_records.py](../../tools/maintenance/resource_build_records.py)第15–22、108–119行的MODEL_PRODUCERS/model_specs漏掉`card_definition_compiler.gd`。真实调用为model_template_builder第33–35行→CardDB.get_card→compile_definition→DEFINITION_COMPILER，决定形态/visual_animations及裁剪clip。可构造：改变编译器的视觉字段/形态合并规则而卡牌/配方不变，第一次check会因全局inputs变化拒绝；write随后按未变model key复用旧.res，只重新解析效果声明并刷新总索引，最终可认证旧模型。纯Python内存中仅改变该snapshot摘要，12个model spec全部相同（未改仓库文件、未运行编译器/生成器）。因此全局hash覆盖不能代替逐产物真实闭包；当前check=0也不否定此失效路径。应补直接语义producer并加窄失效测试，再评估必要生成，不能手改索引续认。
2. **局中补货错误未进入正式失败链（P2）**：[match_model_pool.gd](../../scripts/presentation/match_model_pool.gd)第395–424行将构造/包装/bind错误累加并discard；[battle_presentation_3d.gd](../../scripts/presentation/battle_presentation_3d.gd)第99行只advance_refill，未检查/转发新增errors。Main第461行仅在初始prepare结束检查一次。可构造故障夹具：初始成功后让后续step-bind构造目录/所有权检查失败，空闲库存仍不足，下一帧选中同路径再构造，原错误还使stage1持续失败。期间不触发resource_failed、Main不取消、不会自动恢复；直到后续attach失败才可能间接暴露。应在补货首次失败时明确停止/传播，并窄验一次失败通知及半成品/信号释放；本轮未实际注入或声称正常对局已遇此故障。

另有同一失败合同的次级缺口：UnitModel3D第1598–1601行death-followup工厂返回null时仍调用`instance.queue_free()`；新strict pool.take确实可返回null（未规划路径/准备错误），会抛脚本错误而非有序失败。普通replace_visual第171–173行已做is_instance_valid保护，死亡替身应保持同一拒绝合同。当前纳尔合法路径已在账单中，未声称正常纳尔死亡必现。

已核对但未发现本轮新的实质问题：cancelled setter→_stop_refill→discard owner/node及disconnect process_frame，release_sources先置cancelled再清观察器；正式attach材质错误经UnitModel→BattlePresentation→Main；清单坏格式不回退源JSON；生成worker暂存/回收后串行进Godot、索引最后发布，部分失败由check拒绝，非跨文件事务；发布包装器前置check并在签名/冒烟前核对原生raw字节。完整发布实操仍未验。Jinx当前原位换形复用同根，未把未触达的通用preserve分支猜测写成现行故障。

### 工作区、产物归属与安全清理建议

审查起点442个待提交路径（162已跟踪变动、280未跟踪），无暂存改动。已对这些文件做高置信私钥/常见token模式扫描，0命中；这不是穷尽秘密证明。大于5MiB仅CLPS 10,522,360字节和开发源JSON 86,756,851字节；JSON与HEAD原assets源SHA完全相同，是已知迁移，不是新增候选。12模板共8,602,381字节。最终提交前以最新清单复核，不使用此起点数量冒充最终stage数量。

- 必须提交：assets/generated的90清单/12.res，tools/generated索引/74投影，tools/source_assets可复现源/12配方/旧CLPS审阅，addons门禁及配置、生产消费者/工具/测试/夹具/必要.uid。开发索引/投影是受控构建收据，不当临时缓存删；tools/与addons门禁按现有export排除，不上传本地证据包。
- 必须保留本机：素材库/宣传素材、原始源件、旧新参照快照、失败PNG/日志/guard/审批拒绝、成功结果、索引身份和本轮静态证据；Pantheon候选仅在本地，未误入正式配方或生成集合。
- 可在父任务最终确认后清理：本轮明确创建、已退出且无参照用途的/tmp编辑脚本，命名为tmp/patch/edit的本地脚本先逐项查引用；完整证据中可再生重复包/副本仅列候选，不按体积删除。ignored清单不等于可删清单。
- 不执行：清空.godot/系统缓存、删用户文件/素材/日志、杀其他应用、git clean。此回合实际删除数为0，没有残留引擎由本回合产生；不凭旧PID报告现在的环境已清干净。

静态证据在本机ignored目录`ClashLegends-开发素材库/04-中间产物/构建与验证/preload-static-closeout/`：workspace-inventory.json（逐文件SHA/大小/模式扫描范围）、compiler-closure-witness.json（内存spec对照）、ignored-inventory.json（只列名和体积，不判可删）。不重复上传大包。

### 分批提交与push前最小检查

暂不stage/commit/push。最终建议三批：①相互耦合的生产/生成/门禁/配方/产物及对应回归，含保留的未启用候选基础设施；②不参与产物指纹的独立性能诊断入口/说明；③当前文档、总状态及历史证据索引。不能机械按四阶段拆开共用文件：生成producer SHA、资格pins、包装引用及索引必须与同批内容一致。每批暂存后核对`git diff --cached --check/--stat`及实际路径；若希望更细历史，先重建可独立消费的中间代码身份，再决定是否值得承担额外生成验证。

最小必要集合：先修上述生产发现并只验证直接失败/失效路径；生产输入改变后按既有资格规则审阅受影响项，再做必要增量write与Python-only check。可复用证据必须绑定最终文件/产物身份；未变范围不重复执行历史所有合同。文档audit与diff-check、最终暂存范围/秘密/大文件扫描、生成集合及导出过滤检查必须覆盖最终树。仅实际发布才需要完整导出与原生PCK/冒烟；当前不能宣称已发布验收。最终如要宣称加载优化收益，仍缺同条件受保护整场分段/RSS及必要首用验收，需父任务先确定有限范围，不能用此静态审查替代。

sampled真实复验保持**denied、未执行**：精确目标为`python3 tools/performance/effect_coverage_probe.py --family sampled --render`中的azir/cast1两层；原因是本批一次真实渲染额度已使用，父助手追加不足以替代用户明确批准。授权前不启用四provider、不换命令运行相同实验。其他独立工作可以继续；不能据此把全部收尾状态写成通过。

本轮验证收尾：显式文档verify计划为0套件/无需导入；Python-only `resources --check`前后均0错误；`audit_project.py`为77卡/7172文件/0错误，diff-check通过。起点逐文件SHA复核显示生产、配置、工具、生成产物与测试均未被本轮修改，仅11份文档有本轮增量。ignored盘点只有一个匹配本任务的旧编辑脚本`model-ownership/remaining-models/editing-scripts/edit_remaining.py`，仍保留供来源复核；库环境中同名片段文件不列为可删。完整联调副本等大目录只做体积盘点，不据大小判断废弃。

## 2026-10-19：三处集成修订（当前）

在本任务原有授权内修复上述三处问题，不触及被拒绝的sampled渲染。代码及CPU窄合同已完成；原有沙盾两个辅助pin的范围冲突已获明确授权解决，随后增量生成及独立check均0错误。下面保留此前105项过期错误的阻塞过程；最终续记、原新字节对照及边界见本节末尾。不据此宣称五阶段整体验收完成。

- resource_build_records.MODEL_PRODUCERS加入CardDB.get_card→compile_definition实际调用的card_definition_compiler.gd，原schema已覆盖。配方cards仍限定各模型卡定义，不扩到全卡库。纯Python内存摘要对照：编译器变更12模型dirty；无关twitch卡变更0模型dirty；aatrox卡变更仅aatrox模板dirty。新增两项测试还覆盖实际mock generate不会把旧模型收据重新认证，且离线worker不启动、CLPS/投影全部复用。
- MatchModelPool新增失败信号，advance_refill发现错误先置cancelled，清半成品及帧信号，再只通知一次；begin_bind错误在本步立即传播。BattlePresentation在_init连接到已有_material_failure，继续进入Main既有_fail_preparation。初始prepare原失败路由保持。
- UnitModel3D死亡替身的工厂null/错误根不再无条件queue_free；正式attach提供model_factory_errors读取原池错误，经UnitModel→BattlePresentation→Main保留原因。没有错误源的工具工厂得到包含场景路径的明确错误，不静默视为正常结束。

实际验证：`test_resource_incremental.py`14项纯Python/mock通过（原12+新2）；首次headless故障合同24项通过后，仅补齐包装/begin_bind两个分支并复验最终38项。四阶段各自触发一次原错误，验证Main生产路由（只stub最终UI/完整世界末端）、取消、半成品释放、实际帧信号断开、后8帧不构造/不重复报告；另验证真实strict pool.take返回null及无错误源的null工厂。只加载小型material_plan夹具，不建完整对局或效果播放器；未运行sampled/--render、首用画面或性能对局。

最终故障证据为`model-inventory/20261019-053515-212328/`：38项/0失败、1.112787秒、峰RSS376,029,184字节、cleanup confirmed/无活组成员。原20秒/1GiB、6秒启动/2秒主线程心跳、ready增长256MiB、30FPS、normal及8/4GiB门槛不变。首次默认沙箱因保护观测不可读在引擎前停止，随后获自动审批允许相同headless合同；没有编译错误、没有渲染审批重试。

此前因资格限制暂停时的静态计划（历史，后续已实际完成）：12模型需重建，90清单因resource_build_records生产器身份需刷新；CLPS计划reuse，74投影计划reuse，offline worker无需启动。所有旧正式产物字节保留。该次Python-only check明确105错误：沙盾两个资格源pin、全局输入过期，以及12模型/90清单的旧record；这不是模型文件损坏，也不是通过。必须先明确是否允许仅续记现有沙盾两份辅助源码的审阅证据（不新增资格、不改变sampled），然后沿既有write/check恢复；该次未擅自续记；后续明确许可及实际结果如下。

增量源码diff、原新逐模型key、producer字段差异、四份真实变化输入SHA及规划保存在`preload-static-closeout/integration-fixes/`的before/、invalidation-and-plan.json、core.diff与receipt.json；该次沙盾资格SHA保持；后续只续记明确许可的两个辅助pin，旧新SHA另保存在pin-renewal/review.json。无commit/push/删除/环境清理，所有历史失败和成功证据保留。sampled azir/cast1真实复验继续denied、未执行，与本轮资格pin阻塞分开记账。

### 两个沙盾辅助pin显式续记与必要生成完成

父任务随后明确许可只审阅并续记已启用沙盾的pool/UnitModel两个辅助源码pin。逐项核对本次core.diff及before源快照：pool的prepare、stock实例准备、材质闭包、take/recycle、draw、instantiate，UnitModel的setup/replace、buff挂接/最终变换/advance及release共13个正常路径函数体逐字节相同。沙盾其余9个资格输入（含provider、两Shader、场景、共享覆盖器和执行器）SHA及完整sample摘要相同；beam整条记录相同。仅追加此次38项CPU故障证据及适用边界，资格总数仍2，没有sampled资格或opt-in。

| 沙盾辅助源码 | 原SHA256 | 新SHA256 |
| --- | --- | --- |
| match_model_pool.gd | c2566f4180a5e96502599925b83e66a369e5fcc9f6b205568ab65b751d49c442 | 17e3ca11d4cac94b8841c23984a84ee8f4060a8952c3d6909c8c3e650d73b106 |
| unit_model_3d.gd | 1010019b86fb1a133e8c3922692bf4543426e66edba02e9cc5da4dc4d11ff988 | d89513c43c6d28ce63e562104e74f6b40a80e1c8737c854081a2dc574f808e91 |

这是对明确diff的人工窄审阅，不是write自动续认。失败分支会停止/传播错误，成功路径没有新绘制或资源创建；继承已有沙盾渲染证据仅限未变视觉路径。本轮没有重拍沙盾宿主、没有sampled实际复验，也不把38项故障合同当作新增视觉证明。14项Python及38项合同的源码身份均未再改变，直接复用，不重复跑。

实际`resources --write`证据为`resource-artifacts/20261019-053910-023313/`：77定义/43provider/90variant，**build102/reuse75/migrate0**；12模型因新增compiler producer重建，90清单因开发生产器身份更新。CLPS及74投影复用、offline-skipped理由no dirty offline products，没有启动worker或重读87MB数值源。生成引擎为headless声明/模型加工，不实例化效果播放器/不渲染；4.572230秒、峰RSS412,483,584字节、cleanup confirmed/无活组成员，沿用原保护阈值。

12模型逐一与原文件完整字节比较**全部相同**：编译器内容/配方/几何算法未变，只是先前漏记的输入现在进入producer收据，产物无需改变才能正确失效。90清单逐项比较均仅policy_sha256变化，selection/resources/raw/source_identity均相同，dependency_changes=[]；CLPS SHA和74投影记录也完全相同。正式新索引包含新的模型build_key及正确输入，不手改hash或复制旧record放行。生成后自动check与独立Python-only check均0错误。

审阅及逐产物证据在同一`integration-fixes/pin-renewal/`：review.json（旧新pin/13函数/证据边界）、models-before/（12原文件，仅本地证据）、generation-comparison.json、receipt.json。旧105错误、默认沙箱保护停止及所有失败/成功结果继续保留。此子任务到一致性恢复为止，无commit/push、无清理用户文件；sampled真实渲染仍denied/未执行，完整加载/RSS/首用与最终提交仍由父任务收尾。

## 分析时结果（历史）

开局等待中混合了四种不同工作：**读取运行数据、加工素材、准备可变实例、让渲染器第一次见到表现状态**。目前用“完整效果预演”和“保守库存”同时承担这些职责，准备量随粒子数量、动画库大小、包装脚本和依赖链增长，缺少按实际覆盖状态收敛的契约。不能把现有采样年龄、绘制次数、哈希和库存原样保留当作优化前提。

建议先做三条通用改造：**把依赖发现及源件一致性检查移到生成／构建；把效果绘制覆盖从资源实例身份改为显式状态；把模型模板加工与实例隔离分开，只创建一次实例动画**。之后再按合法突发需求修订初始库存。不是逐卡削减特效，也不是把准备挪到首次施法。

本轮核对了 CardDB 的 **77 个定义**（64 个可选，含 9 法术、63 unit 条目、5 building；unit 中有 6 张纯生成计划卡），以及声明的 **43 个 provider、90 个不同 provider/variant**。全库静态矩阵见后文。三组原样本闭包并集只有 **51 个定义、79 个声明变体**，不能代表全库性能或完备性。

本报告是独立聚焦分析任务的唯一交付记录。只新增本文与索引；未修改生产实现、测试或性能工具，未启动 Godot、重预热、全牌库压力加载、提交或推送。实施方案均未执行，新的加载收益未知。

## 1. 证据口径与现状

- 审查基线：HEAD `f4a0fb79a4b47374653aa28a751899f5dba4c1cb`，加任务开始时已有的工作区修改。原身份集合去重、默认关闭的观测回调、性能工具及相关文档／UID 均保留，不归本次新实现。
- 实测均引用[此前基线记录](2026-10-18_preload_baseline.md)及原始 `loading.json`。A0 是短诊断成功样本，A1 是身份集合优化后一次 A；B/C 各一个有效样本。它们不是均值、冷磁盘／冷驱动数据或全库外推依据。
- 环境由四份原始 JSON 重新核对：Godot `4.7.1-stable (official)`、`gl_compatibility`、Apple M5，实际窗口 `900×1600`；当前 `project.godot` 仍配置权威视口 `720×1280`、Compatibility。没有新启动，不能声称重新测得当前窗口或驱动状态。
- 静态盘点从 `CardDB.DEFINITIONS` 出发，读取四域定义及 11 个派生定义的继承、覆盖、erase、append，按编译器的域合并方式整理**与依赖相关的字面量**。同时读取模型场景的字面量依赖和全部 provider 的 manifest。没有加载资源、实例化模型或展开全库数值帧。
- 该轻量脚本不是 GDScript 解释器：数值表达式不求值，不能代替真实 `CardDB` 编译／validator、动态加载审计或实际渲染。下文全库数量是**源码声明清点**；运行时数量只引用既有真实 collector 样本。未把静态来源表冒充一场合法对局。
- 本机复核文件：`ClashLegends-开发素材库/04-中间产物/preload_mechanism_review_20261018/`，包含 `source_inventory.py`、`source-inventory.json`（77 行及卡源指纹）、`model-provider-inventory.json`（场景字面量闭包和 manifest 原文）、验证结果。它们属于 ignored 分析产物，无需重复上传大包。

## 2. 用户看到的等待究竟是什么

入口：[Main._load_battle](../../scripts/main.gd) → `_prepare_match_assets()`。顺序是串行的：加载页先等两帧 → 建战场 → 固定本场依赖计划 → 收集及加载文件 → 音频池 → 模型库存和展示样本 → 地面效果／目标状态 → 效果预演 → 结束两帧／不足一秒补时 → 联网时等待对手 ready。

菜单之前还有全库定义编译与 `CardDB.validate_all(false)`，以及备战卡面缓存。它们不能混入确认卡组后的计时。`false` 不检查所有资源，不是开局在逐张深度验证全库美术。卡面裁剪强引用在 `_prepare_match_assets` 的 plan 计时之前，现有指标没有单列这笔 CPU；总时间仍包含它。

### 同口径的既有成功样本（秒）

| 工作 | A0 | B | C | 含义 |
| --- | ---: | ---: | ---: | --- |
| 确认到加载完成 | 14.961 | 8.376 | 10.051 | 工具外部截点 |
| Main total | 14.935 | 8.343 | 10.020 | 内部父时间，不能与下一行相加 |
| 建战场 | 0.104 | 0.102 | 0.095 | 场景、地图、塔等 |
| 依赖计划 | 0.023 | 0.005 | 0.034 | 卡牌、技能、阵营、派生闭包 |
| 资源阶段 | 2.288 | 1.701 | 1.622 | 主线程收集／校验＋后台加载等待 |
| 音频准备 | 0.002 | 0.003 | 0.002 | 这不是全部音频文件加载成本；文件加载在资源阶段 |
| 模型池 | 3.331 | 3.923 | 2.598 | 库存、动画、展示样本、状态和绘制 |
| 地面及塔目标状态 | 0.013 | 0.012 | 0.772 | C 包含腐蚀 20 步准备 |
| 效果 | 9.148 | 2.574 | 4.867 | 数据解析、粒子生成、扫描及等绘制帧 |
| 效果内 frame wait | 6.440 | 2.312 | 3.710 | **效果子时间**；不等于纯 GPU 或可全部删除的时间 |

这张账单已经足以确定先审效果与模型，而不是继续打磨毫秒级音频注册。它还不足以把资源阶段拆成磁盘、解码、上传或把效果等待全部称为着色器编译。

A1 的确认到完成为 14.259 秒、效果 8.408 秒、retain 观察 21.958ms；A0 对应 retain 751.317ms。44 配方／226 draw／234 跳过保持。这个已存在优化证明线性重复查询曾有实际成本；不能把单次总差 0.702 秒当稳定收益，也不能再次计入本轮方案。

## 3. 机制级必要性账单

下表“风险”是代码可构造的故障条件或既有合同关注点，除注明实测者外，**不是本轮运行复现**。“保留”也不表示必须保留当前实现时机或数量。

| 工作项与代码入口 | 全库适用范围、触发／规模 | 已有耗时 | 为什么做；直接省略的风险 | 判定及最小验证 |
| --- | --- | --- | --- | --- |
| CardDB 编译、冻结、语义校验；`card_db.gd:all/validate_all`、Main `_ready` | 每进程缓存 77 定义；进入菜单前 | 确认后样本未单列 | 类型／跨卡引用错误应启动失败；省掉会使错误延迟至生成／施法 | **保留快速语义门禁**，全资源检查归开发／构建；不把它当 15 秒主因 |
| 依赖计划；`match_resource_plan.gd:for_match/_references/_filter` | 双方 8 槽＋系统四兵，按阵营／主动选择递归；同定义多次 `_filter` 会浅复制并构造能力字典 | A/B/C 23/5/34ms | 缺换形／召唤／镜像主动会首次使用才读文件；全量则误载未选技能 | **保留可达语义，复用派生结果**；生成闭包边与技能字段归属，运行只选；用静态闭包对照，不先做大框架 |
| 卡面保留；`CardArt.retain_match_textures` | 仅双方卡组；此前缓存64条降到15条（双方有重卡） | 单独未知 | 手牌／下一张／复制显示需要；衍生实体卡面未必在战斗 UI 用到 | **按 UI 消费分型**；不能仅因召唤依赖就把其封面当战斗必需。闭包实体卡面目前也被通用 `_collect` 收集；先核对显示消费者再裁 |
| 递归搜 `res://`；`match_resources.gd:_collect/_prepare_card` | 整份已过滤定义含模型、技能图标、音频、卡面；路径字典去重，期望类型另记；所有世界资源每场一次 | 资源阶段见上；A 主线程 preparation 526ms、threaded wait 1.761s，二者不是额外相加阶段 | 保留资源强引用、缺文件／错类型明确失败；删全部检查可把错纹理当场景延迟崩溃 | **运行保留加载失败／类型边界**；构建清单替代运行全树发现。资源重入已有缓存，不是每个字段都重读同文件 |
| 效果依赖发现；`effect_resource_manifest.gd:files/dependency_data` | 每个 request 解析；同 provider/variant 不同 card 的 request 仍可重复；大文件依赖头每次核对源 SHA | A 资源准备父段包含，逐源耗时未知 | 依赖头陈旧会漏贴图／Shader；现实现失配后静默走完整 JSON 解析，可能突然很慢 | **前移到生成／构建，并按来源复用**；开发显式指出过期，发布消费版本化运行清单。改纹理／层开关／Shader策略时构建必须失败或重生，禁止靠mtime |
| 后台 ResourceLoader；`prepare_async/_accept` | GUI 128请求窗口，线程数由引擎决定；缓存命中不排队；原 A/B/C 845/580/697 请求，863/600/716路径 | 完整资源阶段2.288/1.701/1.622s；无逐类型解码数字 | PackedScene依赖、纹理、Shader、音频本来就要驻留；漏集导致首用加载 | **保留实际可达集合**；先删无用依赖、运行加工和重复校验，再评窗口。无证据改线程／renderer |
| sampled JSON／CLPS 解码；各 `player.gd:load_kind/prewarm` | 每 provider/kind 首次建立静态 data、mesh、material模板缓存；后续实例命中缓存；小原生 systems 有些按实例解析 | 单效果及虚空局部见第4节；各类累计未知 | 运行确需帧数据；完整 JSON 变 Variant 数组很重但不是校验本身 | **数据表示前移、数据读取保留**；复用已存在CLPS技术但不盲目全转。先按源字节和首次parse排名，只转重数据 |
| 源SHA＋载荷SHA；`compact_particle_samples.gd:read` | 当前虚空召唤一个CLPS；每进程首次缓存各一次；dependency头另有源SHA | 局部274.071＋425.861ms | 源改缓存未生／载荷损坏；哈希不能证明生成器逻辑正确 | **重审运行时责任**，第4节给分层；结构边界保留，完整一致性前移或每包版本一次；收益只知局部量级 |
| 模型需求；`match_model_pool.gd:build_specs/_team_demand` | 各卡／阵营默认2，系统4；召唤累加×两波、上限32；镜像整侧×2上限64；按模型路径合并上限64 | 计算未单列；影响后续实例数 | 库存不足时`take`同步创建和bind；但这些数字不是证明过的最小并发需求 | **拆资源集合／初始库存／库存上限**；保留闭包，依据合法首波＋补货期限重定数量，第6节 |
| 库存实例化及bind；`MatchModelPool.prepare`、`ModelVisualResources` | 初始约半库存／至少deployment_count；任一脚本或首次instantiate>1ms则提升到满库存；每份创建独立动画及材质状态 | A145实例，instantiate306ms／animation950ms；B249，382ms／1154ms；C76，9ms／236ms | 活体player/skeleton/loop/material参数必须隔离；删隔离会串动作和状态 | **保留隔离，消除重复复制／模板加工**；实例化计时包含`_ready`，不能只看显式wrapper耗时 |
| 模型展示样本；同`prepare` | 每 path 的 `_warm_signature`一次；**另造样本，不从batch领取**；保留隐藏节点但移除动画库 | A sample_prepare367ms；B383ms；C211ms | 样本要有真实蒙皮、附属层／材质；但额外完整动画副本只为预演后即丢 | **复用模板或可安全借用一个库存实例**；保证还原、隐藏／回收、源和信号隔离；节省量未知 |
| 全动作起点、受击／冻结／强化／金身／隐身、入场样本 | 所有可达模型；动作mesh/material组合已有去重；stasis/freeze按plan开关，强化基础别名已有跳过；入场6点 | A121 draw/724动作跳过，B159/1004，C131/248；金身27/36/0样本 | 初次蒙皮／多遍／冻结／金身可能晚编译；姿势不同本身不证明新渲染状态 | **状态覆盖保留，运行加工可前移**；预导出动作→可见mesh/material状态，不再遍历完整库推测 |
| 隐身／冻结候选材质创建；`ModelVisualResources.begin_bind/_prepare_stealth_materials/_overlay_variants` | 每个bind都建立隐身材质备选和基础三态；即使该模型无隐身、该局无freeze；draw门禁不等于创建门禁 | animation段含材质扫描／创建，纯成本未知 | 不可达状态无需创建；原始材质快照仍服务恢复 | **按能力及本局状态只建可达变体**，保留还原快照；不以“懒到首用”替代准备 |
| 地面准备；`SpellEffectWarmup.prepare_ground` | freeze每变体4点force_draw；corrosion20点0–4.75s，force_draw后又等process_frame；未统一效果去重器 | C ground772ms；A/B约12ms | 延迟层需要覆盖；固定20步未证明每步新状态 | **归入同一覆盖协议**；保留投影、畸变／范围层、首出生和动态结构，删除无新状态等待 |
| 效果setup、seek、retain、scan、draw；`spell_effect_warmup.gd` | 完成键provider+variant；sample按默认9年龄＋逐层首次可见，view固定32步；每龄递归retain、可见资源扫描；模型附属准备还可再做同类效果 | A44配方226draw/234跳过；B19唯一配方84/81；C40配方170/175；等待见表 | seek发现晚层／扩池；draw预备渲染；retain防资源提前回收。三者混在一起不能整段删 | **拆CPU准备、覆盖、绘制三职责**；第5节给具体替代；计数是现状，不是验收目标 |
| 同局retain身份集合 | 每个首见Resource强引用一次；每龄仍递归 | A1观察22ms（已实施） | 按路径合并会误合并两个私有材质；跳整节点会漏新子节点 | **复用现改动**；不再为此重复优化或重跑A |
| 一秒最短展示／帧边界／联网ready | 结束两帧；不足1s补时；网络等待另计 | 三样本padding=0，opponent_wait约0 | ready不能在准备完成前放开；UI补时没有资源作用 | **可独立取消补时**但当前三样本无收益；不能把帧信号等待全部删掉 |

## 4. 校验和素材加工，哪些应该离开开局

### 虚空召唤：不是只读一个10MB文件

既有单播放器、headless CPU样本：源JSON **86,756,851字节**，CLPS **10,522,326字节**，解压载荷 **134,420,536字节**。setup共807.255ms，内含源SHA274.071、读取压缩数据1.152、解压38.970、载荷长度与SHA425.861、数组构造约34.925、偏移检查等0.805、几何模板2.935、材质模板26.187ms。哈希两段约占本局部86.7%。

这里源SHA在验证“可编辑源和产物匹配”，载荷SHA在验证“解压内容符合产物头”；后者的425.861ms不是简单`size()`长度比较。依赖发现还在另一个阶段通过`.dependencies.json`验证同一源SHA，没有跨阶段复用证明。不能把807ms与GUI A的setup约550ms或整场资源段相加，它们环境／缓存和计时范围不同。

**建议的责任划分（尚未实现）**：

| 阶段 | 必做 | 故障如何明确暴露 |
| --- | --- | --- |
| 资源生成／导入 | 完整源hash、结构／维度／有限值、逐数据等价、payload hash；生成依赖、采样覆盖、格式版本与生成器版本 | 源改动而产物过期直接生成／构建失败，指出源及需重生文件 |
| 开发运行 | 按明确开发策略检查产物身份；允许严格模式；源失配不应悄悄展开87MBJSON兜底 | 加载页给出“产物过期，需生成”；不以静默旧缓存开战 |
| 发布构建 | 从固定清单打包运行产物，验证全部source→artifact映射、FileAccess文件纳入PCK、依赖／禁用层／Shader选择一致 | 缺产物、过期、导出漏文件令发布失败；可编辑源不是运行必需依赖 |
| 发布运行 | 保留magic、schema、头长上限、维度乘积／最大字节、解压成功与长度、offset端点／单调／范围、数组边界 | 损坏或版本不匹配明确准备失败，禁止静默回原JSON |
| 安装／更新／包版本完整性 | 依据实际打包／更新渠道决定一次包级校验或首次版本校验；未查清渠道前不能宣称可直接移除payload hash | 防同长度有效压缩的损坏；记录已校验包身份和失效条件，不能只用mtime或“上次没事” |

结论是**支持把源SHA移出每次开局**；不再沿用“必须运行时两份SHA原样保留”的旧限制。payload完整hash能否同样移走，取决于包完整性边界，不能靠一句“ZSTD能解压”代替。结构校验只需处理少量头及offset，和整块134MB哈希应分开计时和决策。

### 全库同类工作

依赖头目前有22份；它们减少大数组JSON解析，却仍用全源SHA验证，每个request都可能重做。90个声明变体由109处声明引用；`prepare`的绘制完成去重不覆盖`files`的解析工作。应生成不可变运行manifest，按`source identity + parser version + layer policy + shader policy`复用解析结果；request再补card/radius上下文。**不能缓存一份经过技能／system筛选的数据给另一变体**。

确定性模型加工也在运行重复做：网格表面过滤、三角形过滤、披风拆面、加法动画合成、绝对轨道转换、长度裁剪、高度轨道追加。这些结果大多只依赖源和加工参数，应产生导入／离线模板；播放器、骨骼姿态、当前形态和可变材质留实例。全库不是只有剑魔存在这种工作，见第7节。

## 5. 效果预演应按什么覆盖，而不是按多少年龄

### 现在做了什么

`_sample`优先用`resource_sample_ages()`，其次只要存在`_data`就扫描其frames并使用通用年龄；只有两者都没有才用`recipe.times`。因此manifest里写的`times`不一定生效。`scale`字段在当前执行器也未被读取，setup硬编码`0.01`；不能把manifest字段存在当作已落实的预热契约。

通用年龄为0.025、0.05、0.1、0.2、0.4、0.8、1.5、2.5、4秒（按duration截断），另补每层第一个非空frame；trail要至少两点。它证明“抽到某层”，**没有计算最大同时粒子数，也没有证明所有渲染分支都被覆盖**。

播放器seek按采样时刻粒子数增长`_pools`，为新粒子复制ShaderMaterial。seek后遍历全树保留资源，再遍历可见节点收集mesh/surface/material/shader RID。静态ArrayMesh且材质可审计时，已画同组合可以跳过；任何CanvasItem、PrimitiveMesh、ImmediateMesh、非Mesh几何、标准／未知材质、多遍或overlay都会`force`。这是安全的保守规则，**不是这些类型每龄都需要一次完整战场绘制的证据**。

预演结束`player.free()`／`view.free()`，留下资源强引用和static data/mesh/material模板。正式事件重新new播放器，重新建立私有粒子节点／材质；**预演临时池并未移交正式事件池**。因此“要预建所有这些粒子，不然首用卡顿”并非当前实现已经兑现的保证。降低临时预演数量是否损失首用平滑，应分别测首次解析、CPU实例创建和渲染编译，不能笼统用池扩容解释226次draw。

### 可以具体删减／改写的覆盖类别

| 覆盖类别／具体代码 | 现在的保守工作 | 应保留的覆盖单位；可删除的工作 | 必要性证据／最小验证 |
| --- | --- | --- | --- |
| sampled静态ArrayMesh；虚空召唤、多个通用player | 新粒子即使同Shader、同格式，也因私有material RID不同触发新draw | Shader／渲染模式、顶点与蒙皮格式、实际材质链／纹理能力；模板CPU准备与代表性可见粒子。**不必预演每个私有material身份**，前提是变体键经过审计 | 静态可确认shader选择来自blend／distortion／no_depth；纹理、skinning和状态差异必须进键。先选一个纯静态player核对首次真实事件，再扩相同实现家族 |
| PrimitiveMesh程序效果；蚂蚱R、沙盾、皮克斯吸血、虚空再生 | PrimitiveMesh一律force；空emitters的`_data`仍取得多个默认年龄 | 稳定球／quad几何和材质分支，各代表性可见状态；**不能只为opacity／phase变化每龄等帧** | 再生configure一次已建9个wisp与球；各龄主要更新位置、uniform／显隐。它还在模型buff样本另做3次绘制。先核对两处覆盖归属并合并，不删附着覆层 |
| 2D beam／天使光剑焰浪 | CanvasItem一律force；多年龄重建polygon | 顶点通道、blend/sub和Shader类型、纹理／图集状态；代表性线／带／命中几何 | 实际2D渲染路径另有状态，不能用3D同Shader键覆盖；但移动端点／改宽度不是“新增Shader”的证据 |
| ImmediateMesh／trail；龙王R导弹／wave、赏金trail、凝滞flight | 同RID持续清空重建surface，每龄force | 空→首段、顶点通道／拓扑结构、材质／透明／深度状态、确实需要的新缓冲形式；把纯位置变化与结构变化分开 | 不能按RID跳过。但也没有理由把11个位置年龄视为11个新管线。先对一个trail记录surface格式／材质状态及CPU构建，再选代表结构；保留首段与迟生层 |
| 附着蒙皮；腕豪full_body/cast_body | 每recipe另外实例化同腕豪宿主；标准主体或overlay使多个年龄force | 真实skinned mesh、attach shader和多遍链；宿主几何可共用准备上下文，当前实例隔离保留 | A full_body10draw并非10个新skinning模式；不能删宿主。先一个宿主覆盖两recipe，对比挂点和首次附着 |
| view入口；电击、大电击、凝滞、酒桶、烈阳 | 每variant固定32步，每0.1秒重同步、扫描；通用去重只挡一部分draw | 生命周期事件：飞行／预警、到达／命中、拖尾、晚层、结束；阶段内按新增状态提交 | A凝滞32步仅12次draw；已经跳过20次，也未证明剩下12次不可减。酒桶还包含tail、hit不能只画impact；电击2.15秒后直到3.1秒的尾段不应默认必需 |
| ground入口；冰面／腐蚀 | 脱离通用覆盖器；腐蚀force_draw+process_frame×20 | 地面范围mesh、screen/depth畸变、粒子层与迟出生；运行数据可预计算覆盖时刻 | C772ms是该入口总时间，最多是待审范围，不是可省772ms。统一状态记录后删除重复阶段 |
| 模型附属效果；梦魇／蛮王／各buff | 梦魇`prepare_resource_sample`固定20次force_draw；其他附属状态与provider采样可能重叠 | 基础材质、附着next_pass、粒子、命中触发分别指定owner，覆盖结果可复用 | 7个dependency-only provider中部分依赖模型或专用入口；不能因为SpellWarmup没sample就断言漏热，也不能重复准备来回避归属 |

**通用替代方案**：生成期产出“依赖、可见层首次出生、trail首段、生命周期阶段、渲染状态签名、CPU模板需求”清单。运行准备数据／模板，然后逐个尚未覆盖的状态创建可见代表样本并提交绘制；覆盖提交后才记录完成。动态几何按格式／阶段版本记录，不以RID代表内容；同Shader文件也不能自动等价，须包含材质链、skinning、depth/screen、blend/cull/depth等会影响渲染的上下文。uniform值如果确实改变可达分支，须明确列代表分支，不能猜测。

完整画面与首用测量继续负责证明流畅和正确；年龄采样仍可留作离线美术QA，**不再让它同时承担运行时依赖发现和整套动画播放**。先让一个简单家族成功，再接trail／附着／screen-depth家族。无需先造K=2、两个完整世界或跨效果合帧；原同世界遮挡、屏幕／深度纹理和共享ground问题仍有效，但不构成阻止更简单删减的理由。

## 6. 对象池数量：有界启发式，不是合法并发的证明

资源可达集合回答“可能用什么”；初始库存回答“首次突发马上要几份”；上限回答“愿意保留多少”。当前三者部分纠缠：

1. 每卡每阵营至少2；系统兵线至少4。遍历每个来源定义的召唤、死亡、转化和主动引用，按字段`*_count`累加；互斥形态取最大，但不同事件来源相加，再乘基础deployment_count和两波系数，child上限32。
2. 只要该侧demand里有`copy_deck_skills`，所有demand×2（上限64）。**没有核对每个需求是不是镜像实际能复制的牌组来源**；仅系统自动兵线的根也会翻倍。主动镜像的技能扩展检查前两槽，而库存翻倍检查有无镜像，二者不是同一条件。
3. 同模型路径合并容量上限64；同卡互斥形态同路径只记一次库存，但不同路径仍各准备。初始取需求约一半、至少deployment_count；只要有脚本或首个实例耗时>1ms，就改为满容量。硬件／当次缓存会影响这个判断。
4. 补货仅支持被判safe的路径；不足库存的`take()`仍同步instantiate＋bind。capacity是保留／准备预算，**不是运行活体硬上限，也没有从规则上消除所有miss**。

既有样本的直接量级：

| 同一个既有样本 | 全池路径／初始实例／容量 | 具体可复核现象 |
| --- | --- | --- |
| A0 | 31／145／192 | 虚空鱼40份全建、虚空兽12份全建；剑魔两形态各4，凯隐三路径各4；附属场景也占池，不只有定义模型 |
| B | 36／249／322 | 近战虚空鱼32、远程虚空鱼36、虫子24、黄沙士兵20均全建；雾行者16／32、虚空螨12／24可半量；不是所有召唤都昂贵，也不是所有都可延后 |
| C | 28／76／128 | 多个buff等附属场景各2份；模型instantiate仅9ms，但render约1.610s，不能一概用减少实例解释此组模型成本 |

**应改的通用规则**：保存每项需求的来源、是否可部署／镜像、同一事件重复成员、每次突发量、最早重复间隔、可否互斥、创建／回收能力。先把静态网格及动画加工前移，让带脚本的轻量包装也能声明分步构建／重置能力；再用真实首次突发数量＋补货截止时间设初始库存。没有补货证据的慢模型不能先砍库存。

可先修正不可能复制的系统来源翻倍、互斥事件机械累加、附属场景一概默认两份等来源不清问题；每项必须在可达来源图上给依据。两个周期重叠、召唤后再召唤、死亡补生、主动镜像应有有限合法轨迹。用这些轨迹查miss、首次／补货最长主线程步骤和还原，**不需要把77卡一起塞进战场**，也不需要先测无限刷兵压力。

## 7. 动画与模型加工：全库分类及一次创建所有权

| 分类及源码 | 当前实际工作 | 可前移／复用；保留什么 |
| --- | --- | --- |
| [剑魔包装](../../assets/units/aatrox/aatrox_view.gd)，2形态 | 本场共享高度／网格模板已存在；`_ready`先copy_library成活体，通用bind再复制；样本另造同链 | **确定存在完整重复链**。模板加工可导入；一份实例库明确移交bind，摄影直接wrapper入口也要拿到自己的库 |
| [太阳圆盘](../../assets/units/sun_disc/sun_disc_view.gd)，蓝红2场景 | `prepare_visual_animations`全库deep duplicate并裁Attack轨道；无prepared守卫，通用bind再复制 | **不只剑魔**。裁剪变导入模板，准备入口幂等；活体最终只复制一次 |
| [虚空之门](../../assets/units/void_gate/void_gate_view.gd) | `_ready`复制library容器，Spit／Death动画副本，逐key将Spit差值合成绝对值并延长Death；bind再复制 | 不是全库都复制两遍；确定性两片段加工前移，原delta模板仍供运行叠加读用 |
| [牧魂人](../../assets/units/yorick/yorick_view.gd) | 披风拆面、两层私有材质／随机phase、IdleIn副本裁到1秒、添加两个骨骼modifier；再bind | 拆面／裁片段前移；UV随机、材质参数、modifier/player引用留实例；复制裁剪片段后又复制有重复 |
| [纳尔](../../assets/units/gnar/gnar_view_filter.gd)，2形态 | `_ready`过滤mesh/三角形、加法缩放轨道烘完整动画，bind复制生成库与原库 | mesh／动画纯加工可导入，最终实例动画隔离保留；不能把源channel计成实际引擎轨道 |
| [天使](../../assets/units/kayle/kayle_view.gd)2路径、[女皇](../../assets/units/belveth/belveth_view.gd)、[奥恩](../../assets/units/ornn/ornn_view.gd)、[赛恩](../../assets/units/sion/sion_view.gd)、[虚空鱼](../../scripts/presentation/voidfish_model_view.gd)2路径 | 每实例过滤／重建ArrayMesh；部分改纹理与私有next_pass材质。此组不是已证实动画双复制 | 只读几何模板按源／配置版本复用；私有火焰／颜色／显隐引用保留实例 |
| [潘森](../../assets/units/pantheon/pantheon_view.gd) | 活／死mesh过滤、材质附加、死盔modifier、arrival prepare | 过滤几何和arrival依赖前移，怒气材质参数、宿主引用和动态落点保留 |
| 凯隐3路径、蚂蚱、龙王、虚空兽、虫子等包装 | 多为modifier／挂点／效果状态初始化；龙王`_ready`主要找嘴骨 | **不能称全都有动画双复制**。但只因带script便取消clip筛选、全建库存，过于粗糙；按能力声明实际额外clip／可变资源需求 |
| 无脚本模型 | 已按visual_animations并集筛片段及RESET，copy_track，库内alias只复制一次；运行补货可分step_bind | 复用现优化；不要退回全量深拷贝，也不能把同一活体Animation跨单位共享 |

已知A1剑魔普通／终极路径总时间406／434ms；其中instantiate124／158、animation133／134、sample_prepare68／65ms。这些是父子段，bind还含网格／材质等，**不能承诺移交协议省掉267ms或整个路径**。

建议一次创建协议：构造者先接收只读模板与需要的clip／变体；`create_instance_resources`创建最终独立Animation并标出owner／模板身份／覆盖版本；通用binder验证并接管已有实例资源，或者对普通导入库创建一次。wrapper与独立摄影共用该创建入口，不能靠“有prepare方法就跳过”猜所有权。

共享限于只读导入资源和确定性派生模板。Animation.loop_mode／key、AnimationPlayer、Skeleton、骨骼modifier引用、材质uniform和当前形态必须独立；同一库内明确alias可保留。回池恢复loop、section、骨骼／变换、材质、形态、附属状态和信号。最小合同覆盖两个实例互相不影响、模板不变、摄影直wrapper、换形／死亡／回收、分步补货，不启动整场重卡组来代替所有权证明。

## 8. 全牌库机制与资源类型覆盖矩阵

这是审查矩阵，不是“已全部预热验证通过”列表。

| 机制／资源类 | 全库源码范围 | 现路径覆盖与遗漏／扩张点 | 建议合同 |
| --- | --- | --- | --- |
| 基础模型、动画、贴图、卡面 | 62定义有直接模型，65个不同主模型路径；21个附属场景路径，合并主模型后共85；贴图含GLB／场景传递依赖，不能用65当全部贴图数 | `_collect`递归字面量＋ResourceLoader传递导入；buff、死后场景也进池；视觉源路径同为字符串，没有用途分型 | 明确primary model／attached／death followup／UI-only／raw，构建出依赖，运行按用途创建 |
| 阵营变体 | 木桩、四类系统小兵、太阳圆盘6定义声明visual_scene_paths；音频team_overrides同按阵营过滤 | team=0/1可达路径保留；主模型库文件仍可带多个皮肤，不能按定义路径数断言只载了相应Mesh | 渲染／素材变体键含阵营能力；库存按实际路径合并；未出场侧不加载 |
| 同卡transformed_stats | 金克丝、纳尔、剑魔、赛恩4定义 | 两形态分别取配置；Jinx同路径不重复库存；某些transformed字段归主动，未选须过滤 | 形态边明确是否被动／主动；采样覆盖与同时库存分别声明 |
| 成长／升级／死亡替身 | 凯隐→刺客／暗裔；天使→远程；冰鸟↔蛋 | INHERIT传主动选择；闭包去重终止环；蛋↔鸟不会无限累计。转化为不同card与同卡form不同 | 生成边类型化、是否继承主动明确；不一律复制所有技能／库存 |
| 召唤／转化／冲撞生成 | 虚空召唤／女皇→鱼；蚂蚱→虫；门→单兽；皇帝→沙兵／圆盘；璐璐→pix；墓碑→imp；先锋→螨；远程鱼再生自环 | 基础召唤不继承主动；成长／替身继承。数量启发式会把不同事件加总；自环只扫描一次，并非真实持续并发上界 | 单次突发、事件互斥、重复间隔与主动资格，分别驱动资源／库存 |
| 编队 | 六种小兵部署卡；黄沙守卫6、pix5、虚空兽2、远鱼3／军团6、奥拉夫2为旧deployment_count型 | spawn_plan重复成员代表数量，不能按唯一成员漏计；旧同质编队还用各自数量 | 资源成员集合去重、数量不去重；成员技能映射不是只凭index默认兼容 |
| 主动槽／普通镜像／完整镜像 | 多技能候选：蚂蚱、梦魇、盖伦、治疗、格温；镜像前两槽允许全队牌组所选主动被复制 | `_filter`fields擦除未选能力；未声明字段默认base；copy_deck_skills只扩本方。库存翻倍比实际复制来源粗 | 技能拥有字段、继承规则、复制范围必须可审计；新增能力漏声明会无用加载或漏热 |
| 法术目标状态 | stasis基础→金身全模型／塔；freeze基础iceborn→冻结；trundle仅减速 | 未携带状态不draw，但部分候选材质仍创建；免疫水晶不金身 | 本局目标状态准备；材质创建门禁与draw门禁一致，运行新状态不得绕过准备 |
| 隐身／地面／附着／弹体 | 老鼠隐身；freeze/corrosion地面；7个dependency-only provider及附属／弹体入口 | 只看SpellWarmup会漏看模型附属、predeploy和弹体prepare；重复入口也可能做同一资源状态 | 每项标一个准备owner和消费事件；多个入口共享覆盖记录，不各自保守全演 |
| 音频 | 70个定义含音频文件字面量；世界／比赛另加；可达事件、形态、team过滤 | 文件IO在resources，prepare_audio只建随机器／循环副本；`pool`组合缓存已存在。基础attack音池不全走pool随机器 | 构建事件→文件；运行复用pool，循环WAV副本保留隔离；毫秒级注册非首要热点 |
| 原生文件／导出 | manifest json/raw、播放器mesh JSON、CLPS、render_order | FileAccess文件不由Godot普通导入保证；source header、sample data、mesh又在不同阶段读 | 版本化运行清单＋导出包check；不能只检查editor里存在 |

### 新卡必须遵守的通用依赖／准备契约（建议，尚未改schema）

1. 声明资源用途和归属：基础、哪个主动、哪个形态／阵营、召唤边及是否继承主动；UI、世界、模型、附着、弹体、地面、raw分开。动态拼接路径必须进入生成清单。
2. provider声明可消费事件和variant，以及**明确的准备owner**；dependency-only要指出由哪个模型／地面／弹体入口覆盖，不能靠目录命名或中央英雄名单。
3. 离线manifest包括生成器／格式／source身份、禁用层策略、Shader选择策略、依赖和覆盖样本。运行不扫完整数值帧找贴图，不再次加工确定性几何／动画。
4. 覆盖样本表达状态或阶段，区分CPU数据、几何／材料模板、GPU代表提交；采样times、scale要有真实读取方和validator，不能放无效提示字段。
5. 模型声明只读模板、最终实例可变资源和一次移交；不因新增轻量脚本就自动复制全动画库或强制满库存。
6. 池声明首次合法突发及创建／重置／补货能力；资源可达不等于全容量预建。首次技能顺畅仍是验收要求，不能把缺货同步创建当“完成优化”。
7. 新卡检查生成清单／单个provider覆盖和合法事件轨迹即可，复用同实现家族合同；只有出现新渲染机制才增加家族验证，不每卡重复整个牌库。

## 9. 实施排序：收益未知也要明确下一步删什么

“预计影响”按现有热点范围和扩展频率排序，不是承诺秒数；各行重叠，不能把预算相加。

| 顺序 | 可评审的实施范围 | 预计影响／证据强度／复杂度 | 最小验证与通过条件 |
| --- | --- | --- | --- |
| 1 | 生成版本化依赖清单，去掉运行对源件SHA和完整JSON依赖发现的需要；复用相同source的解析；虚空源件与CLPS身份随构建绑定 | **中到高**；存在大源读／hash和重复request的静态证据，虚空局部hash实测强；中复杂度。整场收益未知 | 不启动战场：改变源件、禁用层、Shader策略应令生成／check失败；合法产物依赖集合等价；导出包不带源件也能读运行数据；坏头／长度／offset仍拒绝；payload完整性另定包边界 |
| 2 | 效果覆盖契约，先实现纯静态ArrayMesh或程序PrimitiveMesh一个家族；固定view32步改事件阶段；ground接同一覆盖记录；删只有uniform／位置变化的重复等待 | **最高待释放范围**：A效果8.408s、等待6.676s（A1口径）；静态保守规则确定，真正可省量未测；中复杂度，trail／screen-depth后做 | 单provider受保护试验，覆盖日志列“新增状态／纯更新／新增节点”；核对晚层、实际图像、首个正式事件CPU与帧时间。以覆盖和首用表现验收，不保持draw计数 |
| 3 | 模型确定性加工前移；剑魔／太阳圆盘先建通用一次创建移交；脚本按声明clip筛选；样本不再造无用途完整动画副本；不可达隐身／freeze材质不创建 | **中到高**：各样本模型2.598–3.923s；双复制链静态强，纯可省时间未知；中复杂度 | 两实例＋摄影直wrapper的所有权窄合同；改单实例loop／key、形态、死亡、回池不影响另一实例及模板；覆盖最终真实蒙皮／材质状态 |
| 4 | 按来源拆池预算；去不可能镜像的系统扩张、互斥来源重复；支持轻量脚本分步补货后重定初始量 | **中**，B249实例说明乘数明显，但没有首用轨迹证据；规则／生命周期复杂度中高 | 先静态需求来源账单；有限合法首波／主动／死亡／镜像轨迹，miss与最长步骤满足既有首用要求。慢路径未改造前不缩库存 |
| 5 | 再决定重JSON扩展CLPS、导入二进制Mesh／动画模板、会话级只读缓存 | **中，因卡而异**；数值解析／geometry转换确定，逐类型累计未知；格式与内存复杂度中 | 单源原数据逐位／等价、版本失效、导出和驻留内存；只读缓存按产物身份释放，不能让全库常驻换时间 |
| 后置 | 128加载窗口、调度交叠、跨效果合帧、全局Shader资产归并 | 收益未知；先删无效工作再考虑；合帧复杂度高 | 只有上述改造后的剩余profile显示必要才测；共享Shader需完整render-mode兼容，不能只按文本类似合并 |

最先需要的**新实验**不是再跑一次重卡A：假设“虚空再生／沙盾这一类固定PrimitiveMesh的多年龄force draw没有引入新的渲染状态，CPU模板和附着覆盖可各准备一次”。最小实验只选其中一个provider，在既有监督器内一份样本＋一次正式消费；记录每龄geometry格式／材质链／Shader及新增节点，保留早／晚可见状态，比较首次消费和实际图像。使用既有20秒／1GiB／30FPS局部预算、normal与余量门槛、心跳／清理；超限停止，不扩大数量或预算，不自动转整场。本轮仅提出，未启动。

如果先实施源校验前移，先做不需要GUI的产物完整性合同；如果实施动画移交，先做两实例合同。待一个家族通过，再进行一次同条件代表对局确认总收益，避免为每个小改动反复跑三套重卡组。整场采样必须同时验证首用，不接受仅加载数字变快。

## 10. 仍未知的边界

- 全库每类ResourceLoader解码／纹理上传／Script编译时间、各provider首次解析／材质创建与GPU编译占比，没有现成分项，不伪造估算。
- 旧观测有resource_keys数量与force标记，但没有每个覆盖键对应的语义／格式变化；无法事后精确算出226次中多少必需。需要上述单家族证据，不能按RID或固定K盲删。
- 79个样本声明变体不等于79项实际绘制：其中dependency-only和ground由其他入口负责，未选主动也会使variant不进入样本。没有对全90项作渲染验收。
- 模型池不同参数组合的首波／最早重用需求与补货安全性尚未证明；现有“有脚本→满建”说明保守，不直接证明满建每份都无用。
- 发布／增量更新的完整性边界未专项审查，payload hash移出运行必须补这个条件。
- 原A首次等待至少52秒未复现，退出ObjectDB警告未归因。两者仍未解决，不能用本报告声称修复。

## 11. 2026-10-18：本轮文档改动与验证

- 新增本机制分析、全库卡牌／provider附录及分阶段方案；索引增加本任务链接。没有更新当前架构为未来方案，没有改上一任务“当时不实施”的历史事实；本报告明确重新审查其限制。
- 验证范围限定本文与`docs/deliveries/README.md`，与已有生产／工具脏文件分开；`verify --plan --changed ...`只选文档audit和diff-check，0领域套件、无导入。随后同范围`verify`通过：项目审计77卡／6935文件／0错误，差异检查通过。
- 轻量静态交叉检查通过：77定义、43provider、90变体；此前三组collector的106条request逐条能回到本次对应卡定义的声明；矩阵主模型／附属场景路径均存在。该检查确认来源匹配，不证明所有潜在运行依赖完整或渲染通过。日志见本机证据目录`static-crosscheck.json`和`verify/`。
- 未运行引擎、领域套件、渲染、音频或联网；不把引用的旧验证当本轮通过。

## 附录A：77定义逐项来源矩阵

下表由本轮轻量源码盘点生成。M=不同主模型路径数，X=该定义中其他场景路径数，S=主动候选数，E=效果声明出现次数（含主动／形态，未按本场选择）；音=不同音频文件字面量数。M/X不是实际导入依赖总数，E不是实际配方／draw数。“样本”仅指进入前三组既有collector闭包；共享模型可能已被其他条目间接准备。全部行链接权威定义，派生继承已纳入。

| 定义（类型／可选性） | M/X | S/E/音 | 生成／形态依赖 | 样本 |
| --- | ---: | ---: | --- | --- |
| [void_summoning／虚空召唤](../../scripts/data/cards/void_summoning.gd)（spell／可选） | 0/0 | 1/1/3 | spawn_id→voidfish | 有 |
| [scuttle_crab／峡谷迅捷蟹](../../scripts/data/cards/scuttle_crab.gd)（unit／可选） | 1/1 | 1/4/7 | — | 有 |
| [void_scuttle_crab／虚空迅捷蟹](../../scripts/data/cards/void_scuttle_crab.gd)（unit／可选） | 1/1 | 1/3/10 | — | 有 |
| [malzahar／虚空先知](../../scripts/data/cards/malzahar.gd)（unit／可选） | 1/0 | 2/5/19 | spawn_id→voidling；active_skills.1.spawn_id→voidling | 有 |
| [voidling／虚灵](../../scripts/data/cards/voidling.gd)（unit／衍生或工作台） | 1/0 | 0/1/9 | — | 有 |
| [void_gate／兹若特传送门](../../scripts/data/cards/void_gate.gd)（building／可选） | 1/0 | 1/4/4 | spawn_id→void_spawn_single；active_skills.0.spawn_id→void_spawn_single | 有 |
| [void_spawn／虚空兽](../../scripts/data/cards/void_spawn.gd)（unit／可选） | 1/1 | 1/5/9 | — | 无 |
| [void_spawn_single／虚空兽（单只）](../../scripts/data/cards/void_spawn_single.gd)（unit／衍生或工作台） | 1/1 | 1/7/9 | — | 有 |
| [azir／沙漠皇帝](../../scripts/data/cards/azir.gd)（unit／可选） | 1/0 | 1/4/5 | assist_conversion_unit_id→sand_soldier；assist_conversion_building_id→sun_disc；active_skills.0.spawn_id→sand_soldier | 有 |
| [sand_soldier／黄沙士兵](../../scripts/data/cards/sand_soldier.gd)（unit／衍生或工作台） | 1/1 | 1/2/11 | — | 有 |
| [explosive_cask／爆破酒桶](../../scripts/data/cards/explosive_cask.gd)（spell／可选） | 0/0 | 1/1/4 | — | 无 |
| [nocturne／永恒梦魇](../../scripts/data/cards/nocturne.gd)（unit／可选） | 1/1 | 2/2/17 | — | 有 |
| [jinx／金克丝](../../scripts/data/cards/jinx.gd)（unit／可选） | 1/1 | 1/2/19 | 同卡双形态 | 有 |
| [corki／库奇](../../scripts/data/cards/corki.gd)（unit／可选） | 1/0 | 1/2/18 | — | 有 |
| [target_dummy／训练木桩](../../scripts/data/cards/target_dummy.gd)（building／可选） | 2/1 | 1/2/14 | — | 有 |
| [corrosion／腐蚀法术](../../scripts/data/cards/corrosion.gd)（spell／可选） | 0/0 | 1/1/1 | — | 有 |
| [tryndamere／蛮族之王](../../scripts/data/cards/tryndamere.gd)（unit／可选） | 1/1 | 1/1/21 | — | 有 |
| [tristana／麦林炮手](../../scripts/data/cards/tristana.gd)（unit／可选） | 1/1 | 1/2/14 | — | 有 |
| [belveth／虚空女皇](../../scripts/data/cards/belveth.gd)（unit／可选） | 1/0 | 1/0/10 | death_spawn_id→voidfish | 有 |
| [voidfish／虚空鱼](../../scripts/data/cards/voidfish.gd)（unit／衍生或工作台） | 1/0 | 0/1/7 | — | 有 |
| [voidfish_ranged／远程虚空鱼](../../scripts/data/cards/voidfish_ranged.gd)（unit／可选） | 1/1 | 1/3/7 | active_skills.0.spawn_id→voidfish_ranged_single | 无 |
| [voidfish_ranged_army／远程虚空鱼大军](../../scripts/data/cards/voidfish_ranged_army.gd)（unit／可选） | 1/1 | 1/3/7 | active_skills.0.spawn_id→voidfish_ranged_single | 有 |
| [voidfish_ranged_single／虚空鱼（远程）](../../scripts/data/cards/voidfish_ranged_single.gd)（unit／衍生或工作台） | 1/1 | 1/3/7 | active_skills.0.spawn_id→voidfish_ranged_single | 有 |
| [twitch／图奇](../../scripts/data/cards/twitch.gd)（unit／可选） | 1/0 | 1/1/25 | — | 无 |
| [lulu／璐璐](../../scripts/data/cards/lulu.gd)（unit／可选） | 1/0 | 1/0/13 | spawn_id→pix | 有 |
| [pantheon／潘森](../../scripts/data/cards/pantheon.gd)（unit／可选） | 1/1 | 1/1/36 | — | 无 |
| [kayn／凯隐](../../scripts/data/cards/kayn.gd)（unit／可选） | 1/0 | 1/0/16 | growth_ranged_id→kayn_assassin；growth_melee_id→kayn_slayer | 有 |
| [kayn_assassin／影流刺客](../../scripts/data/cards/kayn_assassin.gd)（unit／衍生或工作台） | 1/0 | 1/0/16 | — | 有 |
| [kayn_slayer／拉亚斯特](../../scripts/data/cards/kayn_slayer.gd)（unit／衍生或工作台） | 1/0 | 1/0/16 | — | 有 |
| [shurima_guard／恕瑞玛卫队](../../scripts/data/cards/shurima_guard.gd)（unit／可选） | 1/1 | 1/2/11 | — | 无 |
| [garen／盖伦](../../scripts/data/cards/garen.gd)（unit／可选） | 1/0 | 2/0/32 | — | 无 |
| [xin／赵信](../../scripts/data/cards/xin.gd)（unit／可选） | 1/0 | 1/0/24 | — | 无 |
| [ashe／艾希](../../scripts/data/cards/ashe.gd)（unit／可选） | 1/0 | 1/0/19 | — | 无 |
| [teemo／提莫](../../scripts/data/cards/teemo.gd)（unit／可选） | 1/0 | 1/0/15 | — | 无 |
| [gnar／纳尔](../../scripts/data/cards/gnar.gd)（unit／可选） | 2/0 | 1/0/30 | 同卡双形态 | 有 |
| [melee_minion／近战兵](../../scripts/data/cards/melee_minion.gd)（unit／可选） | 2/1 | 1/0/21 | — | 有 |
| [ranged_minion／远程兵](../../scripts/data/cards/ranged_minion.gd)（unit／可选） | 2/1 | 1/0/15 | — | 有 |
| [minion_squad／小兵分队](../../scripts/data/cards/minion_squad.gd)（unit／可选） | 0/0 | 1/0/0 | 成员 melee_minion×3, ranged_minion×3 | 无 |
| [melee_minion_squad／近战兵小队](../../scripts/data/cards/melee_minion_squad.gd)（unit／可选） | 0/0 | 1/0/0 | 成员 melee_minion×4 | 无 |
| [ranged_minion_squad／远程兵小队](../../scripts/data/cards/ranged_minion_squad.gd)（unit／可选） | 0/0 | 1/0/0 | 成员 ranged_minion×3 | 无 |
| [heavy_minion_squad／重装部队](../../scripts/data/cards/heavy_minion_squad.gd)（unit／可选） | 0/0 | 1/0/0 | 成员 super_minion×1, siege_minion×1 | 有 |
| [super_minion_squad／攻城部队](../../scripts/data/cards/super_minion_squad.gd)（unit／可选） | 0/0 | 1/0/0 | 成员 super_minion×2 | 无 |
| [siege_minion_squad／炮车部队](../../scripts/data/cards/siege_minion_squad.gd)（unit／可选） | 0/0 | 1/0/0 | 成员 siege_minion×3 | 无 |
| [siege_minion／炮车兵](../../scripts/data/cards/siege_minion.gd)（unit／可选） | 2/1 | 1/0/15 | — | 有 |
| [super_minion／超级兵](../../scripts/data/cards/super_minion.gd)（unit／可选） | 2/1 | 1/0/21 | — | 有 |
| [pix／皮克斯](../../scripts/data/cards/pix.gd)（unit／可选） | 1/1 | 1/1/9 | — | 有 |
| [pix_single／皮克斯（单只）](../../scripts/data/cards/pix_single.gd)（unit／衍生或工作台） | 1/1 | 1/1/9 | — | 无 |
| [freeze／冰冻](../../scripts/data/cards/freeze.gd)（spell／可选） | 0/0 | 1/2/1 | — | 有 |
| [stasis／凝滞法术](../../scripts/data/cards/stasis.gd)（spell／可选） | 0/0 | 1/1/10 | — | 有 |
| [heal／治疗术](../../scripts/data/cards/heal.gd)（spell／可选） | 0/0 | 2/0/3 | — | 无 |
| [zap／电击法术](../../scripts/data/cards/zap.gd)（spell／可选） | 0/0 | 1/1/3 | — | 无 |
| [lightning／大型电击法术](../../scripts/data/cards/lightning.gd)（spell／可选） | 0/0 | 1/1/3 | — | 无 |
| [mirror／镜像法术](../../scripts/data/cards/mirror.gd)（spell／可选） | 0/0 | 0/0/0 | 本方牌组复制（特殊主动） | 有 |
| [masteryi／剑圣](../../scripts/data/cards/masteryi.gd)（unit／可选） | 1/1 | 1/0/18 | — | 无 |
| [twisted_fate／卡牌大师](../../scripts/data/cards/twisted_fate.gd)（unit／可选） | 1/0 | 1/0/30 | — | 无 |
| [gwen／格温](../../scripts/data/cards/gwen.gd)（unit／可选） | 1/0 | 2/1/41 | — | 有 |
| [sett／腕豪](../../scripts/data/cards/sett.gd)（unit／可选） | 1/0 | 1/5/27 | — | 有 |
| [tombstone／墓碑](../../scripts/data/cards/tombstone.gd)（building／可选） | 1/0 | 1/0/6 | spawn_id→imp；death_spawn_id→imp；active_skills.0.spawn_id→imp | 有 |
| [apex_turret／H-28Q尖端炮台](../../scripts/data/cards/apex_turret.gd)（building／可选） | 1/0 | 1/0/19 | — | 无 |
| [sun_disc／太阳圆盘](../../scripts/data/cards/sun_disc.gd)（building／可选） | 2/0 | 1/1/13 | — | 有 |
| [aurelionsol／龙王](../../scripts/data/cards/aurelionsol.gd)（unit／可选） | 1/0 | 1/9/23 | — | 有 |
| [anivia／艾尼维亚（冰晶凤凰）](../../scripts/data/cards/anivia.gd)（unit／可选） | 1/0 | 1/2/15 | death_replacement_id→anivia_egg | 有 |
| [anivia_egg／冰晶凤凰蛋](../../scripts/data/cards/anivia_egg.gd)（unit／衍生或工作台） | 1/1 | 0/0/4 | timed_revival_id→anivia | 有 |
| [missfortune／赏金猎人](../../scripts/data/cards/missfortune.gd)（unit／可选） | 1/1 | 1/5/31 | — | 有 |
| [imp／雾行者](../../scripts/data/cards/imp.gd)（unit／衍生或工作台） | 1/0 | 0/0/7 | — | 有 |
| [aatrox／剑魔](../../scripts/data/cards/aatrox.gd)（unit／可选） | 2/0 | 1/0/17 | 同卡双形态 | 有 |
| [rift_herald／峡谷先锋](../../scripts/data/cards/rift_herald.gd)（unit／可选） | 1/0 | 1/0/18 | rush_spawn_id→voidmite | 有 |
| [voidmite／虚空蠕虫](../../scripts/data/cards/voidmite.gd)（unit／衍生或工作台） | 1/0 | 0/0/12 | — | 有 |
| [kayle／正义天使](../../scripts/data/cards/kayle.gd)（unit／可选） | 1/0 | 1/0/13 | deployment_upgrade_id→kayle_ranged | 有 |
| [kayle_ranged／正义天使（远程）](../../scripts/data/cards/kayle_ranged.gd)（unit／衍生或工作台） | 1/0 | 1/2/16 | — | 有 |
| [sion／赛恩](../../scripts/data/cards/sion.gd)（unit／可选） | 2/0 | 1/3/43 | 同卡双形态 | 有 |
| [darius／德莱厄斯](../../scripts/data/cards/darius.gd)（unit／可选） | 1/1 | 1/0/22 | — | 无 |
| [ornn／奥恩](../../scripts/data/cards/ornn.gd)（unit／可选） | 1/0 | 1/0/23 | — | 无 |
| [olaf／狂战士](../../scripts/data/cards/olaf.gd)（unit／可选） | 1/1 | 1/4/20 | — | 有 |
| [olaf_single／狂战士（单只）](../../scripts/data/cards/olaf_single.gd)（unit／衍生或工作台） | 1/1 | 1/4/20 | — | 无 |
| [kassadin／虚空行者](../../scripts/data/cards/kassadin.gd)（unit／可选） | 1/0 | 1/3/21 | — | 有 |
| [yorick／牧魂人](../../scripts/data/cards/yorick.gd)（unit／可选） | 1/0 | 1/0/18 | — | 无 |

## 附录B：43个provider全部登记变体与准备归属

下表共90个不同provider/variant，仅列卡定义实际声明的变体，不把provider支持但无人声明的额外模式加入。sample=独立播放器采样，view=32步事件模拟，ground=地面入口，依赖=manifest本身没有前三类配方。依赖行仍可能由模型／弹体／入场入口准备；必须跟踪对应消费者，不能据此断言已覆盖或遗漏。

| provider（链接源码） | 登记variant | 准备入口／数据 | 声明来源 |
| --- | --- | --- | --- |
| [assets/effects/aftershock/burst.gd](../../assets/effects/aftershock/burst.gd) | default | sample；JSON  | target_dummy |
| [assets/effects/aftershock/native/player.gd](../../assets/effects/aftershock/native/player.gd) | Buff | sample；JSON  | target_dummy |
| [assets/effects/anivia/player.gd](../../assets/effects/anivia/player.gd) | storm, missile | sample；JSON  | anivia |
| [assets/effects/aurelionsol_q/player.gd](../../assets/effects/aurelionsol_q/player.gd) | beam, end | sample；JSON  | aurelionsol |
| [assets/effects/aurelionsol_r/player.gd](../../assets/effects/aurelionsol_r/player.gd) | tell, missile, impact, strong_tell, strong_missile, strong_impact, wave | sample；JSON  | aurelionsol |
| [assets/effects/azir/beam_player.gd](../../assets/effects/azir/beam_player.gd) | basic_attack | sample；JSON  | azir |
| [assets/effects/azir/player.gd](../../assets/effects/azir/player.gd) | cast1, cast2, hit, spawn | sample；JSON  | azir, sand_soldier, shurima_guard |
| [assets/effects/gwen_tristana/player.gd](../../assets/effects/gwen_tristana/player.gd) | rapid, missile, mist | sample；JSON  | gwen, tristana |
| [assets/effects/kassadin/player.gd](../../assets/effects/kassadin/player.gd) | appear, vanish, idle_blade | sample；JSON  | kassadin |
| [assets/effects/kayle/native/player.gd](../../assets/effects/kayle/native/player.gd) | sword, wave | sample；JSON  | kayle_ranged |
| [assets/effects/malzahar/nether_grasp/player.gd](../../assets/effects/malzahar/nether_grasp/player.gd) | zone, beam | sample；资源／程序生成 | malzahar |
| [assets/effects/malzahar/player.gd](../../assets/effects/malzahar/player.gd) | portal_start, portal_end, cast, spawn | sample；JSON  | malzahar, voidling |
| [assets/effects/missfortune_w/player.gd](../../assets/effects/missfortune_w/player.gd) | trail, left, right, end_left, end_right | sample；JSON raw  | missfortune |
| [assets/effects/nocturne/nocturne_effects.gd](../../assets/effects/nocturne/nocturne_effects.gd) | shield, cleave | 依赖；JSON  | nocturne |
| [assets/effects/olaf/player.gd](../../assets/effects/olaf/player.gd) | cas, shield, buf_glow, buf_blood | sample；JSON  | olaf, olaf_single |
| [assets/effects/pix_lifesteal/player.gd](../../assets/effects/pix_lifesteal/player.gd) | lifesteal | sample；资源／程序生成 | pix, pix_single |
| [assets/effects/sand_ward/player.gd](../../assets/effects/sand_ward/player.gd) | ward | sample；资源／程序生成 | sand_soldier, shurima_guard |
| [assets/effects/scuttle_crab/normal_ward_antenna_wake/player.gd](../../assets/effects/scuttle_crab/normal_ward_antenna_wake/player.gd) | default | sample；JSON  | scuttle_crab |
| [assets/effects/scuttle_crab/randuin/player.gd](../../assets/effects/scuttle_crab/randuin/player.gd) | default | sample；JSON  | scuttle_crab |
| [assets/effects/scuttle_crab/shrine_green/player.gd](../../assets/effects/scuttle_crab/shrine_green/player.gd) | default | sample；JSON  | scuttle_crab |
| [assets/effects/scuttle_crab/shrine_red/player.gd](../../assets/effects/scuttle_crab/shrine_red/player.gd) | default | sample；JSON  | scuttle_crab |
| [assets/effects/scuttle_crab/void_ward_antenna_wake/player.gd](../../assets/effects/scuttle_crab/void_ward_antenna_wake/player.gd) | default | sample；JSON  | void_scuttle_crab |
| [assets/effects/scuttle_crab/void_z_visionring_green/player.gd](../../assets/effects/scuttle_crab/void_z_visionring_green/player.gd) | default | sample；JSON  | void_scuttle_crab |
| [assets/effects/scuttle_crab/void_z_visionring_red/player.gd](../../assets/effects/scuttle_crab/void_z_visionring_red/player.gd) | default | sample；JSON  | void_scuttle_crab |
| [assets/effects/sett/player.gd](../../assets/effects/sett/player.gd) | full_body, cast_body, warning, min, max | sample；JSON  | sett |
| [assets/effects/sion_w/player.gd](../../assets/effects/sion_w/player.gd) | Cas, Shield, Nova | sample；JSON  | sion |
| [assets/effects/tryndamere/undying_rage.gd](../../assets/effects/tryndamere/undying_rage.gd) | default | 依赖；JSON  | tryndamere |
| [assets/effects/void_gate/player.gd](../../assets/effects/void_gate/player.gd) | spawn, idle, spit, death | sample；JSON raw  | void_gate |
| [assets/effects/void_spawn/player.gd](../../assets/effects/void_spawn/player.gd) | burst, death, energy, glow, spawn, trail | sample；JSON  | void_spawn, void_spawn_single |
| [assets/effects/void_summoning/player.gd](../../assets/effects/void_summoning/player.gd) | zone | sample；JSON raw  | void_summoning |
| [assets/effects/voidfish_ranged/player.gd](../../assets/effects/voidfish_ranged/player.gd) | spawn, missile | sample；JSON raw  | voidfish, voidfish_ranged, voidfish_ranged_army, voidfish_ranged_single |
| [assets/effects/voidfish_regeneration/player.gd](../../assets/effects/voidfish_regeneration/player.gd) | regeneration | sample；资源／程序生成 | voidfish_ranged, voidfish_ranged_army, voidfish_ranged_single |
| [assets/units/pantheon/pantheon_arrival.gd](../../assets/units/pantheon/pantheon_arrival.gd) | default | 依赖；raw  | pantheon |
| [scripts/presentation/corki_projectile_effect.gd](../../scripts/presentation/corki_projectile_effect.gd) | missile, bullet | 依赖；资源／程序生成 | corki |
| [scripts/presentation/corrosion_ground_3d.gd](../../scripts/presentation/corrosion_ground_3d.gd) | default | ground；JSON  | corrosion |
| [scripts/presentation/explosive_cask_3d.gd](../../scripts/presentation/explosive_cask_3d.gd) | default | view（32步）；JSON  | explosive_cask |
| [scripts/presentation/freeze_ground_3d.gd](../../scripts/presentation/freeze_ground_3d.gd) | trundle, iceborn | ground；JSON  | freeze |
| [scripts/presentation/jinx_projectile_effect.gd](../../scripts/presentation/jinx_projectile_effect.gd) | bullet, rocket | 依赖；资源／程序生成 | jinx |
| [scripts/presentation/lightning_spell_effect_3d.gd](../../scripts/presentation/lightning_spell_effect_3d.gd) | zap, lightning | view（32步）；JSON  | lightning, zap |
| [scripts/presentation/locket_effect_3d.gd](../../scripts/presentation/locket_effect_3d.gd) | default | view（32步）；JSON  | sun_disc |
| [scripts/presentation/sacrifice_leap_3d.gd](../../scripts/presentation/sacrifice_leap_3d.gd) | default | 依赖；资源／程序生成 | void_spawn, void_spawn_single |
| [scripts/presentation/stasis_spell_effect_3d.gd](../../scripts/presentation/stasis_spell_effect_3d.gd) | default | view（32步）；JSON  | stasis |
| [scripts/presentation/stealth_transition_3d.gd](../../scripts/presentation/stealth_transition_3d.gd) | default | 依赖；资源／程序生成 | twitch |
