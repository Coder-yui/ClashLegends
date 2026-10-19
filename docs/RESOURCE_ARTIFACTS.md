# 开发生成产物与运行依赖

本流程属于资源制作和发布，不在游戏启动或对局中扫描全库。当前覆盖 CardDB 的全部效果声明；运行准备按本场 provider/variant 读取对应小清单，不解析源件来寻找依赖，也不计算源件 SHA。采样覆盖的后续窄迁移见[效果覆盖契约](EFFECT_WARMUP_COVERAGE.md)，不改变本页的依赖加载责任。

## 操作入口

使用 Python 3.14（紧凑格式生成依赖标准库 `compression.zstd`）及 `godot-version.txt` 指定的 Godot。修改逐卡效果声明、来源 JSON、层筛选、Shader 路由或生成策略后执行：

```sh
python3 tools/dev.py resources --write
python3 tools/dev.py resources --check
```

`--write` 先检查[覆盖资格](EFFECT_WARMUP_COVERAGE.md#覆盖审阅资格与失效)及模型导入前置条件；失败不能自动更新资格。随后按CLPS、每源投影、每recipe模型和每份效果清单的build_key核对真实输入、producer、格式/策略及现存产物SHA。全局快照变化触发轻量声明解析，不等于全部资源重烘焙。无变化且记录/内容均一致时不启动worker或Godot；无dirty离线项时不启动worker。模型单独变化复用已认证CLPS/投影，未脏模型在load/instantiate前跳过。

离线worker只执行显式dirty jobs。确需重建CLPS时源只解析一次，使用单bytearray保留原offsets→全部IDs→全部float64的排列，并执行独立解码/全行位验证；不会按行交错或删除数值校验。其他变化源分别解析并验证数值frames。虚空投影从已认证CLPS的有界header.data提取，不重读数值帧。worker只写暂存产物和最后的完成报告；父进程核对报告/来源/内容身份，合并约3.66MB已验证的小元数据供Godot使用，不读取大源数值图。worker退出/回收、输入未变后才进入Godot。Godot轻量resolve全部请求以发现新增/删除/动态声明，仅生成dirty模型模板，不执行包装器、效果预热、对局或绘制。

两阶段串行沿用原监督器：各20秒/1GiB、6秒启动/2秒主线程心跳、自有组确认清理；Godot30FPS，启动normal/≥8GiB、运行normal/≥4GiB。JSON解析/压缩同样受主线程心跳约束，无后台心跳线程。失败即停，不自动重试或扩限。日志与offline-plan/engine-jobs/actions在开发素材库`04-中间产物/构建与验证/resource-artifacts/`。

`--check` 只运行 Python，重新计算完整内容 SHA 和文件集合，比较源/策略输入身份及产物精确 SHA，检查运行 raw 文件存在与导出过滤；不依赖 mtime、上次成功标签或运行时全库缓存。生成阶段已验证的 CLPS 在输入和产物**内容完全一致**时复用其验证结果；可用 `python3 tools/maintenance/compact_samples.py --check` 独立重做全行和确定性验证。禁止手工修订生成索引来“放行”旧产物。

新卡在 `resource_dependencies.effects` 声明 provider/variant，provider 的 `resource_manifest()` 表达真实依赖。`json` 表示播放器仍在运行时读取的数据；`dependency_json` 仅供开发发现依赖，不随包运行。不得仅为了缩小清单把仍由播放器读取的文件改成 `dependency_json`。`systems`、`sample.kind`、`layer_enabled()`、`emitter_source`、`shader_providers` 和 `resource_shader_path()` 均由同一生成遍历执行，不能按同源文件合并不同变体。新增 raw 文件须在导出 include_filter 中覆盖，漏项生成即失败。

## 格式和失效边界

| 产物 | 内容与所有者 |
| --- | --- |
| `assets/generated/effect_dependencies/<SHA256(provider + 换行 + variant)>.json` | schema=1、generator=`effect-artifacts-v1`、policy=`effect-files-v1`、provider/variant、源内容 SHA、该产物策略输入摘要、variant 筛选声明、去重排序后的 ResourceLoader 与 raw 依赖；运行逐项读取，无常驻全库缓存 |
| `tools/generated/effect_artifacts.json` | 开发专用总索引：完整输入快照和逐产物build_records/schema=1、真实source/producer/格式策略、产物SHA/bytes、完成校验及origin；最后发布，不导出 |
| `tools/generated/effect_projections/*.json` | 每源独立的开发元数据缓存，源SHA/metadata身份与同一总索引绑定，不导出；无记录不直接复用 |
| `assets/effects/void_summoning/sampled.clps` | `CLPS0002`/schema=2、generator=`compact-f64-v2`；源身份、载荷 SHA、ZSTD 压缩的 int64 ID、float64 采样与偏移 |
| `tools/source_assets/void_summoning/sampled.json` | 受版本控制的可编辑源件，移出正式 assets，明确不导出；重建仍可复现 |
| `assets/generated/model_templates/*.res` | `model_visual_template.gd` schema=1；只读动画库与派生网格。当前12份模板覆盖剑魔、太阳圆盘、奥恩、卑尔维斯、赛恩、两种虚空鱼、虚空之门、牧魂人、天使近远程及纳尔大小形态；潘森未迁移。包装场景显式引用，走ResourceLoader/原生资源导出，不是FileAccess raw |
| `tools/source_assets/model_recipes/*.json` | 每模型独立开发配方：来源/输出、卡牌形态闭包、加工操作及审阅过的导入设置SHA；不导出。产物SHA和clip/mesh迁移表进入同一effect_artifacts索引 |

策略闭包保守包含 `scripts/**/*.gd`、`assets/**/*.gd`、`assets/**/*.gdshader`、效果/单位 JSON、开发源 JSON、生成器及引擎版本声明。修改、删除或新增任一输入都会使 check 失败，即使源文件大小和 mtime 相同。无关GDScript修改仍可能要求刷新总索引并轻量解析请求，但只有该产物真实source/producer/格式策略或内容变化才重建；不能用缩小检查范围隐藏相关变化。每份效果头的policy_sha256是自己的closure key，未与全局policy_sha256绑定。schema、策略名称或 CLPS generator 改动必须同步消费者与生成器，不提供旧格式兼容或源 JSON 回退。

当前效果依赖生成输入的内容边界已经按实际调用核对：`CardDB.all()`/编译器只合并逐卡 GDScript 字典；builder 对场景、材质、模型、纹理等 `paths` 只收集字符串，不展开其属性。瑟提 `resource_manifest()` 把 `sett_view.tscn` 字面量返回，实例化在 `load_kind()` 中，生成不调用它；潘森 provider 虽有代理 GLB/纹理 preload，但 `resource_manifest()` 不读取这些对象的属性，实际选择来自 `particle_player.resource_emitters()` → `profile.data()/layer()` 的 integration.json、systems.json 与相关脚本，均已纳入 inputs。金克丝/飞机声明调用的投影准备只消费 `rocket_geometry.gd`/`missile_geometry.gd` 的 FACES，也已覆盖。Shader 选路仅使用发射器 JSON 字段、固定字符串与 `particle_render_policy.gd`，不读取场景、材质、导入设置或 ProjectSettings。当前没有读取 `.tscn/.tres/.res` 属性、`.import` 内容来决定清单的路径；这些运行资源及其传递依赖继续由 ResourceLoader/导出器处理，不为此扩成全仓库内容 hash。第二阶段的静态覆盖声明另在builder中读取已纳入inputs的Shader源码，核对render_mode/uniform和无纹理上下文；声明随sample写入selection。未来若声明/筛选方法开始读取其他内容，必须同步扩展精确生成输入。

生成不是跨文件事务。离线产物留在该次证据目录，完成报告最后写；worker失败、报告缺失、来源/文件SHA不符、退出/回收未确认时，不启动Godot、不覆盖正式CLPS或索引。Godot成功及输入稳定后才原子发布CLPS；JSON清单和最后的索引也分别用同目录临时文件、flush/fsync、os.replace发布。单文件失败不会截断旧文件，临时文件能正常清理时移除；硬终止残留不当作完成标记。Godot原生.res仍由既有生成器写入，未引入整套事务。若模型/部分清单已写入而后续步骤失败，保留原始失败日志和索引，不手工修改SHA、复制旧格式或绕过门禁。修复源件/缺失文件/导出过滤等报错原因后，重新执行 `python3 tools/dev.py resources --write`，成功后再执行 `python3 tools/dev.py resources --check`。write只构建dirty产物、认证复用项、清理期望集合之外的生成孤儿并最后写总索引；重复执行可收敛到同一内容产物。失败后如果部分产物与原索引不同或索引缺失，check 明确拒绝（已有损坏产物夹具）；若失败发生在任何内容改变之前，原内容仍一致则可通过，不能把一次失败标签本身当作内容失效。不会自动 fallback。

清单缺失、未知 provider/variant、坏 JSON/schema/策略/身份/数组/路径会显式加入准备错误。源件或策略内容过期由开发/构建门禁拒绝；运行不重新读取源件去判断过期。CLPS 保留头长度、整数维度、最大分配、压缩/解压长度、载荷 SHA、偏移端点/单调范围、帧/层/行数组边界及基本播放元数据检查。当前发布链没有包级等价运行完整性保证，所以载荷 SHA **继续在运行时执行**，并未前移或缓存。

## 显式旧CLPS迁移

只有`tools/source_assets/compact_reviews/void_summoning_v2.json`中精确pin的旧源、产物、原索引、工具及函数身份允许一次迁移。迁移继承旧完整位验证，origin为reviewed-legacy-v1，明确new_full_source_validation=false，不伪装本次重算。审阅记录区分旧参考编码/解码/位校验主体相等，与新增single-buffer写入的独立字节布局证明/微型精确测试；新buffer编码器并非字面相同，限制逐项保留。write不能自动续认该审阅。任何未知legacy记录不被新摘要盖章；无记录/失配明确重建或报错。散落旧投影没有可信记录，不能直接复用。

## 生成保护的观测与进程边界

resource_process.py在任何budget/version/既有引擎检查可能拒绝之前，先原子保存preflight.json：UTC/单调时间、进程PID、当前父进程RSS、真实pressure/available/physical及原阈值。观测不可读时保存null及具体错误后停止，不用0伪装。拒绝另写rejection.json。运行中health.json保存带时间的系统状态和父RSS，last-rss.json保存实际组RSS及对应系统采样时间；watchdog/guard保留超时、心跳、RSS和自有组清理结果。运行压力触发前先落盘该次触发读数；监测或结果写入错误不被静默忽略。

旧encode、verify_exact和project返回后没有被证明仍引用帧图；明确留在旧父进程的是元数据字典和小报告，allocator驻留尚无全源测量。新worker中的源文本在解析/散列后立即释放，紧凑源的数值图在编码/位验证/投影提取后释放，后续来源逐个处理。更关键的是，worker退出并被回收后，整个worker私有堆和allocator驻留不再属于活进程；父进程没有通过IPC接收这些对象。系统文件缓存和其他应用的内存不在这项保证中，所以Godot前仍重新执行原≥8GiB/normal检查，不能据此跳过保护。

保护/原子写由test_resource_process.py覆盖；test_resource_incremental.py用微型真实codec/worker及mock引擎覆盖no-op/model-only、损坏/缺记录及部分失败恢复，不运行完整项目加工或Godot。完整源重新编码是否在新离线阶段20秒/1GiB及心跳约束内完成仍未证明；后续成功的模型增量生成复用了CLPS，没有重做完整源，不能把微型通过或增量生成等同于完整通过。三处集成修复已补模型编译器producer并通过窄故障合同；现有沙盾两个辅助源码pin经明确审阅续记后，受保护增量生成102份、复用75份，独立check为0错误。12模型字节与原产物相同，90清单仅policy_sha256变化；不新增视觉验证，详见[集成修订](deliveries/2026-10-18_preload_mechanism_analysis.md#2026-10-19三处集成修订当前)。

## 模型模板与一次实例所有权

当前覆盖剑魔、太阳圆盘、整表面过滤家族（奥恩、卑尔维斯、赛恩、近战/远程虚空鱼），以及VoidGate、Yorick、Kayle近远程和Gnar大小形态。配方在开发时按关联卡牌的所有已声明形态收集实际存在的动画片段（含后续形态和动作过渡），额外摄影片段可用extra_clips显式加入。剑魔生成高度复位轨道、空中被动片段和普通/收翼网格；完整网格复用场景已导入资源，不再在模板重复序列化。旧带full的模板明确拒绝，须重新生成；圆盘生成攻击骨骼遮罩。运行包装器只选择模板网格、创建实例SkeletonModifier并声明visual_animation_contract v1，不再重复加工源模型。

生成输入增加配方源目录中的GLB、纹理、导入设置及project.godot；生成器与动画复制实现同样受内容门禁覆盖。逐模型producer显式包含CardDB实际使用的card_definition_compiler及其schema；本模型配方cards列表仍决定逐卡输入，无关卡定义不使模型重建。修改源件后先让Godot编辑器完成导入；write要求缓存及其全部dest_files存在、导入sidecar的source_md5匹配真实源，并按dest_files顺序串联实际文件字节核对dest_md5（包括声明的全部纹理格式）；不能只信sidecar或文件存在。check在缓存存在时执行同一验证，全部缓存及sidecar均不存在的干净检出仍可只检查源/产物；部分丢失或损坏明确拒绝。运行不计算这些缓存hash。修改主GLB的.import参数时，还须先重导入并审阅配方中的import_settings_sha256，write不会自动认可变化参数。这是开发导入资格，不是运行源hash。模型产物缺失、被修改、孤儿或源/配方变化由同一check拒绝；write清理已退出配方的生成.res。不要手动改索引SHA。当前原始GLB仍是包装场景依赖，未承诺不驻留其完整导入动画库。

ModelAnimationInstance记录附着于模型根节点。明确的v1契约包含本根下的AnimationPlayer与只读libraries；管理器创建每实例独立库和Animation，保留别名，然后由ModelVisualResources绑定同一记录。直接摄影prepare同步完成；MatchModelPool创建设置defer_animation_ownership，ready只装模板，普通bind同步完成、补货bind按单clip分步完成。UnitModel3D/展示样本复用相同入口。重复prepare/bind不复制第二份。allowed只将原导入及模板目录中的真实clip名解释为需求，配置字段键不算clip；固定完整模板的空需求表示声明闭包，普通筛选路径的空需求表示完整原来源目录。已准备闭包的子集可复用，扩大到未准备的真实clip明确拒绝且不污染原记录。准备中每step核对库身份，结束及重复begin再核对实际动画集合；晚发错误通过ModelVisualResources传播。换根、未知版本/状态或外部替换已归属库明确失败；无动画的普通静态模型仍合法。loop/key、播放器、骨骼、modifier、形态和可变材质uniform都不能写共享模板。

未迁移脚本包装明确使用legacy-script-unfiltered-v1保守策略，仍可能有自身加工和通用复制；它是迁移缺口，不是新卡默认契约。普通无脚本场景维持clip筛选。池的库存需求与动画筛选独立，现按[库存契约](MODEL_POOL_DEMAND.md)使用真实来源账单和场景显式构造能力；不再用脚本存在或单次耗时决定满建。通用材质始终保留原始overlay/override/surface/shadow快照。绑定必须明确传入mode=match或mode=tool；正式BattlePresentation3D检查卡牌/阵营/路径并设置view.material_states，Main仅为卡牌工作台显式启用tool模式。match的freeze/stealth/stasis及buff集合来自同路径全部形态/阵营的可达并集；初建、补货、计划内库存miss和绘制样本使用相同集合。非战斗附属场景无目标状态候选。冻结/凝滞按整局目标状态保守覆盖双方及衍生物，隐身按真实能力；buff按过滤后的visual_active_buff_scene、视觉半径、实际阵营去重。加载时为每个库存模型准备独立ghost/frost/gold及每个可达buff的节点、overlay链和受击/冻结组合；不是只预建普通overlay。

正式已准备owner只选择候选引用；未声明状态、buff、模式不符或未规划卡牌/路径返回明确错误，传播owner→UnitModel3D→BattlePresentation3D→Main现有资源失败入口，不通过同步创建掩盖漏声明。只有工具显式tool模式允许懒准备。buff挂接/回收不再重建基础hit/frost，层链和动态uniform仍每模型私有。缓存buff固定在模型根，top_level变换在最终模型位姿后同步，不在普通挂接/回收时单独reparent；外部骨骼附属标记为表现几何，不参与模型覆层和包围盒。reset_prepared_visual复位私有状态；模型根出入树与真正销毁分开，release_prepared_visual负责真正释放骨骼附属，避免缓存移交触发旧_exit_tree误清理。preserve_on_form_change须显式支持，当前不含模型overlay的保持节点可交换已准备实例保存时钟；不支持的转移明确失败。

零新增计数只覆盖ModelVisualResources候选及buff make_overlay返回材质链。库存miss仍会同步创建新实例/候选；第四阶段只规范有限库存与分步补货，不保证所有miss不可达；现有动态粒子/拖尾/按帧网格和内部材质分配仍属于后续效果热点，不能据此宣称整个游戏首用零分配或冷GPU无卡顿。

整表面配方用ArrayMesh容器副本后surface_remove，保留原生surface格式、全部顶点通道、LOD、blendshape/模式、名称、材质、custom AABB与shadow mesh；不重建数组来丢属性。material_textures可单独替换纹理，克隆该表面的材质一次；没有实际删除/替换时不输出mesh键，由消费者继续引用导入源。非空shadow_mesh缺少显式映射时拒绝该加工，不默默保留错误影子拓扑；动态uniform、next_pass、骨骼modifier不进入共享模板。mesh_filters.node可用源根相对精确路径，避免同名父节点遮蔽网格。model_template_view.gd统一安装只读网格和根动画契约。近战虚空鱼源网格已是最终单表面，配方不输出任何网格，直接保留导入资源；赛恩只保存unarmed，full直接引用源网格。其死亡部件时序、两种鱼的部署/弹体骨骼与状态仍由各实例管理。序列化后的内建材质不保证与导入资源对象身份相同，值及纹理引用须等价，活体不可写共享模板材质。

VoidGate的Spit绝对动作和Death持帧在开发生成；运行保留导入Spit delta的只读引用及每实例连续Idle相位，不额外序列化原delta或原网格。Yorick身体/披风拆面和IdleIn裁剪前移，随机UV、双层shader与披风/武器骨骼历史仍私有；动作通知只初始化既有模板，不重复扫描动画所有权。Kayle配方显式包含kayle和kayle_ranged两个定义，生成两套静态过滤网格及远程身体纹理；翅膀shader/next_pass和怒气时钟由表面override持有，不能写共享网格材质。Gnar的加法合成保留原始三角权重公式、关键帧时间并集、scale起点映射和两种主体动作；纯函数只在开发生成器使用，运行只选原始/过滤网格和播放片段。

骨骼过滤直接保留原生surface缓冲，仅替换主索引及每级LOD索引；顶点/蒙皮/blendshape/格式/名称/材质/AABB不重新编码。只支持经确认的索引三角形与四权重布局；缺bind、未知shadow、其他布局或空surface/LOD策略明确拒绝，须补实际映射后才能接入。完整原网格仍直接引用导入资源。Pantheon候选的严格死亡姿态对照稳定差14像素，LOD和材质创建顺序诊断未消除，正式包装器已恢复原实现；候选、失败图和数据保存在同一交付记录所指的本地证据目录，尚不属于运行模板覆盖。

窄合同入口为python3 tools/maintenance/model_contracts.py；整表面/材质批使用--batch2（--materials-only仅夹具），--compile-render只编译所选摄影探针；--render另启动一次实际最小渲染，不跑对局或库存。它使用同一监督器；渲染工具保留严格像素比较，失败须检查原始画面，不能仅把安全监督进程完成当作画面通过。--strict-materials运行严格状态/创建计数/真实attach与池入口微型合同，--strict-materials --render运行有限材质对照；金身TIME动画用同帧隔离视口对照，--stasis-only仅复验该状态。--remaining使用实施前源码快照（--baseline）做本批模型数据对照，--consumers-only只检验六个真实模型/形态经正式UnitModel3D接收已准备资源；--select可缩到受影响模型。--remaining --render只拍VoidGate/Yorick/Gnar机制代表，不把已恢复的Pantheon当作通过。直接包装器准备返回结构化错误，模型/相机/封面展台停止失败实例，不偷偷继续摄影。当前结果和剩余项见[交付记录](deliveries/2026-10-18_preload_model_ownership.md)。

## 门禁和导出

- 编辑器启用 `addons/resource_artifacts`，F5/F6 的 `_build()` 调用 check；失败返回 false，中止运行。可用 `CLASH_PYTHON` 指定编辑器使用的 Python。该检查只发生在开发编辑器运行前，插件目录明确排除导出，不进入导出游戏。 `_build()` 用同步 OS.execute 等待检查完成：第一阶段复核时797个输入共225,740,934字节，每次还需散列90份清单169,745字节和CLPS10,522,360字节，合计约236.4MB内容，另有索引读取、目录遍历和文件存在检查；内容可能来自OS页缓存，但仍逐字节散列。不按mtime跳过。F5/F6和工作台开发启动会承担这笔等待，真实耗时未测，不能宣称开发启动整体变快。导出游戏不携带此检查。
- `python3 tools/dev.py workbench` 在启动正式卡牌预览前也调用 check；独立候选模型/素材展台仍允许制作未接入内容。
- `tools/dev.py verify` 对运行脚本、资源、生成和导出相关改动纳入 check；纯文档不额外扫描源件。
- 正式本机发布入口是 `python3 tools/release/export_macos.py`，在启动导入/导出进程前执行 check。导出后 `pck_audit.py` 读取原生 PCK 目录，要求每个 runtime raw 和清单确实以原路径收录，比较其实际包内字节，拒绝开发源/旧依赖头；随后才运行既有发布冒烟。直接点 Godot 原生 Export 或裸 CLI 不能替代该门禁，不作为本项目受验证发布入口。

原生格式收录检查依据 [Godot 4.7 PCK 读取实现](https://github.com/godotengine/godot/blob/4.7/core/io/file_access_pack.cpp)。编辑器运行中止语义见 [EditorPlugin._build](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html#class-editorplugin-private-method-build)。发布工具生成的文件 SHA/临时签名只证明当时构建身份，不能作为删除运行载荷校验的理由；将来增量更新/包级校验需另行设计。

## 窄验证与未覆盖范围

```sh
python3 -m unittest discover -s tools/maintenance -p 'test_effect_dependencies.py'
python3 -m unittest discover -s tools/maintenance -p 'test_compact_samples.py'
python3 -m unittest discover -s tools/maintenance -p 'test_resource_artifacts.py'
python3 tools/maintenance/resource_contracts.py
```

最后一条仅顺序运行两个受保护微型 CPU 进程：格式拒绝合同和没有源工程回退路径的隔离 PCK 消费。它不导出完整游戏，不证明完整发布包、首用画面或实战性能。`DependencyHeaderSuite` 保留注册 ID，内容已改为新产物合同，不再有 `--full-dependency-headers` 或回退旧头测试。

本阶段清单覆盖全部声明效果。仅虚空召唤已转为无源件运行的紧凑采样；其余采样 JSON、网格 JSON、系统/原生组合 JSON 等仍由播放器读取，继续作为运行依赖导出。第三阶段已迁移剑魔/圆盘、整表面过滤家族、VoidGate/Yorick/Kayle/Gnar确定性加工与通用材质可达准备；Pantheon因严格渲染差异保留原加工，音频和其他贴图加工未迁移。第二阶段已完成沙盾及固定单Quad beam的有限覆盖，沙盾模型附属入口复用声明各上下文一次；其余效果仍未全面迁移；库存按独立来源账单重算，部分补足漏计会增加数量，不能以总数量证明流畅；适用范围及一次真实渲染结果见[覆盖契约](EFFECT_WARMUP_COVERAGE.md)。
