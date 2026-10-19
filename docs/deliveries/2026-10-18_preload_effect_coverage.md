# 预加载第二阶段：沙盾状态覆盖原型

本页保留本阶段当时的过程、失败和验证身份；五阶段当前状态及待修问题统一见[静态收口审查](2026-10-18_preload_mechanism_analysis.md#2026-10-19静态收口审查当前)。阶段内“尚未开始/无拒绝”等只描述该次执行，不代表后续全任务状态。

## 当前结果

2026-10-19后续修订：默认uniform的显式override/版本绑定默认值契约完成，撤销float32归一，674项CPU合同通过。父任务追加的azir/cast1两层真实复验仍被自动审批拒绝，命令未执行；正式provider均保持legacy，等待用户明确批准。详见文末默认值修订。

2026-10-19续批：固定 sampled 层家族的生成/运行候选已完成317项有限CPU合同，覆盖4 provider/11variant/72层；**未启用正式迁移**。唯一真实后端进程在材质签名合同处失败，旧新图片/首用计时未执行。进一步真实渲染被自动审批拒绝，本批保留候选供复核；正式provider已恢复旧算法，生成门禁0错误。详见文末。

第二阶段有限原型现覆盖**沙盾ward、蚂蚱R beam**两个家族，停下供复核，未宣称全库完成。沙盾独立效果7→1采样/绘制，模型附属原3次改为同一coverage驱动的1次，两个上下文各保留必要一次；beam使用正式端点/尺寸，旧4年龄改1次。其余70个sample变体及18个非sample声明保持保守策略，库存、画质和renderer未改。

补齐独立覆盖资格：显式审阅记录绑定相关源码和完整sample声明，普通resources --write不能自动认可源码变化后的旧coverage。运行只检查有限uniform、声明样本值域、固定几何/材质及有限非退化变换，不新增运行源码hash。资格仍是具体内容的人工审阅证据，不是连续时间自动证明。

首轮沙盾只渲染一次；后续仅beam渲染一次，未重跑沙盾/全场/全库。新的16项CPU合同、3项资格失效测试、7项既有资源工具测试、1项窄验证路由测试及开发生成门禁通过。两次有顺序诊断都不是稳定性能或完整实战结论；沙盾宿主回调改造仅CPU检查，未重渲染宿主。

没有commit/push、没有上传大包，前序修改保留。无被拒绝、待批准或结果不明的动作。当前接入规则见[覆盖说明](../EFFECT_WARMUP_COVERAGE.md)；以下先保留首轮原始证据，继续实施见末节。

## 2026-10-18：首轮代码与适用边界

基线HEAD `f4a0fb79a4b47374653aa28a751899f5dba4c1cb`，开始时工作区已有第一阶段生成清单、CLPS、门禁以及此前retained身份集合/诊断观察等未提交修改，全部保留。

- 新增 `effect_warmup_coverage.gd`：`plan()`解析策略，`validate_sources()`仅在开发生成读Shader源码，`inspect()`在声明样本核对实际几何/材质/可见性。没有中央英雄名单或跨provider共享RID完成键。
- 沙盾provider增加 `sample.coverage`，`.08`秒同帧覆盖 `shell×1 / grain×24`。固定球体/quad参数、顶点/法线/切线/UV/index、无颜色/UV2/蒙皮，blend_add、分别cull_back/cull_disabled、depth_draw_never、shadows_disabled；普通float参数，零纹理/screen/depth/next_pass/overlay。后续只改elapsed/opacity/位置/scale；生命周期源码没有创建晚层或替换资源。渲染状态详表见覆盖说明。
- `EffectResourceManifest.resolve()`校验opt-in声明；`SpellEffectWarmup`选择声明样本并在实际检查后绘制。错误直接返回、不标记完成或静默回旧策略。保留旧未声明provider的完整年龄/私有资源身份/类型force算法，明确命名为 `legacy-age-identity-v1`，它是迁移期受审保守策略，不代表已经证明完备。
- 删除的只是沙盾该入口的6次重复seek/retain/scan/draw及等待；保留一次真实可见绘制、完整资源构造/强引用、结束销毁临时节点。正式消费仍重新创建，`pool_transferred=false`；没有将临时池伪称为实战池。
- 生成builder执行Shader模式/uniform/无采样器边界检查，coverage进入现有清单selection。完整源策略hash继续由第一阶段门禁承担，运行不读Shader源码或源指纹。它是有限的语法边界检查，不能自动证明任意Shader分支语义；新Shader/生命周期仍需审阅。
- `SpellWarmupSuite.check_static_coverage()`新增窄合同并接入原套件；新单provider探针只调用该方法，不运行重型suite。生产诊断报告新增分段seek/retain/scan和覆盖样本，无权威状态或音频事件。

## 验证与原始证据

本机目录：`ClashLegends-开发素材库/04-中间产物/构建与验证/effect-coverage/`。

1. 按规定先查看 `verify --plan --changed ...`；自动范围17套件且含旧脏文件直接消费者，随后查看显式 `--suite SpellWarmupSuite --changed ...` 计划。实际只运行此轮必要窄合同、单provider渲染、生成门禁和项目审计，不执行完整重型suite/导入/联网。
2. 首次CPU合同 `20261018-230223-656214/`失败：使用了仅ArrayMesh提供的 `surface_get_primitive_type`，PrimitiveMesh不存在该API。没有真实渲染，日志保留。修正为只接受无脚本内建Sphere/Quad，其索引三角形拓扑/通道检查不再调用该API；窄复验 `20261018-230313-456080/` 的32项全部通过。后续真实渲染再次执行同32项通过。
3. 32项包括原7年龄和0/.08/.38/1.999生命周期结构、2秒隐藏、正式status接口及暂停显示/恢复/移除、独立实例资源、坏/未知声明、漏状态、Shader模式失配、overlay/next_pass/skin/隐藏/几何变化/额外ImmediateMesh的拒绝。完整错误数组为空；没有将headless称为渲染验收。
4. **唯一一次渲染** `20261018-230630-806777/`：Godot4.7.1、Apple M5、Compatibility，实际窗口/viewport720×1280，30FPS上限。使用生产configure/bind_model/advance_status及真实mesh/material，独立最小3D上下文；没有宿主模型/整场战斗。先新准备→新建正式消费，再旧准备→新建正式消费；时序、驱动缓存和限帧相位不同，不能称冷启动配对或稳定提速。未再次运行。

| 单次诊断截点 | 新声明路径 | 旧原年龄路径 |
| --- | ---: | ---: |
| 样本/实际绘制 | 1 / 1 | 7 / 7 |
| setup | .203ms | .285ms |
| seek累计 | .017ms | .230ms |
| retain累计 | .024ms | .289ms |
| 结构检查/可见资源扫描累计 | .192ms | .812ms |
| frame_post_draw等待累计 | 126.136ms | 231.348ms |
| prepare墙钟 | 126.700ms | 233.311ms |
| retained资源 | 50 | 50 |
| 正式新建/configure/bind/advance CPU | .265ms | .664ms |
| 首次正式消费等待截点 | 1.707ms | 32.410ms |
| 首次正式消费总截点（含检查/等待） | 2.178ms | 33.475ms |

等待含自然绘制、同步和限帧，不是GPU编译/纯GPU时间，也不是完整游戏帧时间；首用受订阅frame_post_draw时机影响，不能用上述截点宣称普遍无卡顿。新路径首次准备仍有126ms等待，不能把“一次draw”直接换算成33ms。单次结果只说明本次覆盖、画面、正式资源重建未见错误；未测全对局收益或各设备首帧分布。

5. 两张 `declared-formal.png / legacy-formal.png` 目视一致，SHA256同为 `8ee9bfd18f1ff4bc6b60e636c3c3cd2ec656c26714870c1c0c0810713d164d37`。画面在正式消费.08秒取得，PNG在计时结束后写出；GPU读回发生在首用计时后，可能扰动后续阶段，故不把后续帧作为无扰动基准。
6. 渲染监督总墙钟1.623秒，group RSS峰446,955,520字节（426.25MiB），退出0；ready稳定基线433,455,104字节，实际增长cap701,890,560字节，低于1GiB。保留20秒、启动6秒、主线程心跳2秒、30FPS、ready+256MiB、自有进程组确认清理。整机压力normal、启动估计可用60%/约9.6GiB，运行最低58%/约9.28GiB；没有放宽或停止用户编辑器。

最终生成及静态验证结果见下方收尾。

## 剩余机制路线

| 类别/所有者 | 当前明确策略 | 迁移前证据缺口 |
| --- | --- | --- |
| 沙盾模型池附属预演 | 原3年龄/宿主强制绘制 | 宿主状态生命周期及完成所有权；不能只与此入口共享完成位 |
| 其他Primitive效果（含虚空再生/吸血等） | 原年龄和force保留 | 晚可见光流、overlay与next_pass/蒙皮宿主不能套沙盾合同 |
| sampled静态ArrayMesh | 原年龄/逐层出生补点/私有资源身份 | 实际vertex通道、纹理与材质分支、晚层和首用；模板CPU准备与绘制覆盖分开 |
| ImmediateMesh/trail/动态mesh | 原force保留 | 同RID重建缓冲和生命周期最小几何，不能以Shader身份省略 |
| 2D/view复合效果 | 原2D/32步策略 | Canvas状态、飞行/命中阶段、晚层、上下文/纹理能力 |
| ground/screen-depth/蒙皮/多遍 | 原各自策略保留 | 真实深度/屏幕上下文、宿主格式/链、首可见和新状态；分机制契约 |

父任务先复核本原型，再选有证据的下一家族，不能一次把另外89变体都标成已优化。模型加工/动画所有权及库存仍留在第三/四阶段；不以减少临时预演替代正式实例创建优化。

## 2026-10-18：生成与审阅收尾

- `python3 tools/dev.py resources --write` 成功，77定义/43provider/90variant；随后工具自检及独立 `--check` 均0错误。生成证据为 `resource-artifacts/20261018-231022-937724/`。声明引擎仍受20秒/1GiB等原保护监督，CPU声明过程3.513秒、RSS峰313,425,920字节、自有进程组清理确认。没有实例化全库播放器或绘制，Python完整CLPS和源元数据再生属于开发流程。
- 与第一阶段最终 `20261018-223403-244453/declarations.json` 对照：90份resources/raw集合逐项完全一致；selection仅沙盾ward增加coverage。全90清单的policy摘要因新增通用脚本/策略输入而更新，未把全部清单变化误称为全部变体优化。CLPS文件SHA与实验前完全一致。
- `review/phase2-key-code.diff` 包含本阶段8个关键源码/工具/测试文件的全部差异；对共享脏文件按本阶段hunk逆向恢复开始正文并保存 `review/phase2-before/`，保留第一阶段及更早的retained/observer修改，不以HEAD全差异冒充本阶段。`review/evidence.json` 保存这8个文件的SHA、90集合对照和渲染保护/截图一致性摘要。最终8文件与唯一渲染实验开始时身份完全一致；实验后仅改文档和重生清单。
- `python3 tools/maintenance/audit_project.py` 0错误、`git diff --check` 通过；Python新探针语法检查通过。初次审计在交付记录尚未创建时指出一个临时断链，补齐记录后通过。不因文档收尾重跑已通过的CPU/渲染。
- 没有运行完整SpellWarmupSuite（它会准备大量其他效果），没有导出PCK、F5全局、音频/联网或实际宿主对局首用；不复用第一阶段旧结果宣称当前全域通过。通用状态覆盖只验证了此处列明的边界，下一批仍需父任务决定。

## 2026-10-18：语义资格修复、沙盾附属与单Quad继续实施

只读复核先发现缺口：原全源hash使旧产物过期，但重生成不会自动证明旧coverage完整；晚时刻才创建的层、保持uniform列表的Shader语义修改可能不被单点检查发现。本轮授权继续后，新增开发专用 `coverage_reviews.py / effect_coverage_reviews.json`，不增加运行hash或审批服务。

### 独立资格与窄失效合同

- 两份显式资格分别绑定沙盾11个、beam7个相关输入的精确内容SHA和完整sample SHA；交集为覆盖器、执行器和引擎版本。沙盾还包含provider/Shader、buff场景、ActiveBuffVisual3D、UnitModel3D、ModelVisualResources、MatchModelPool；beam包含provider/Shader、正式MalzaharEffect3D和投影辅助。无关文件变化不撤销这些资格，普通依赖门禁原范围未收窄。
- `resource_artifacts.generate()` 在CLPS生成和引擎调用之前检查记录源身份，变化直接失败；声明收集后、写清单前检查static资格存在、完整sample相符、player/Shader均纳入输入。`--check`同样核对；write不写资格文件。资格须经审阅/必要窄验证后显式更新，不能用复制新hash代替审阅。
- `test_coverage_reviews.py` 3项通过：有效fixture先通过；模拟GDScript晚创建节点、保持uniform列表但改变有效GLSL计算，两者均使实际generate入口在encode/引擎之前拒绝，资格文件字节不变；无关文件变化不影响资格；无资格/遗漏Shader/改变setup拒绝。测试只使用临时小文件和mock，不启动引擎。
- 运行新增所有float uniform有限值检查、可选样本值域及有限非退化global transform检查。beam声明strength样本值域[.1,1]，拒绝alpha为零的无效代表。没有把float类型自动等同语义安全；资格绑定的源码审阅才是允许变化的依据。
- 资格记录仅引用本轮已有源码审阅、沙盾首轮有限渲染、新附属CPU合同及本轮beam实验；未称连续时间自动证明。记录和检查器不导出，运行不读取它们。

### 沙盾两个上下文各一次

provider的 `prepare_resource_sample()` 去掉硬编码`.08/.25/1.0`循环，改为 `EffectWarmupCoverage.prepare_attached(self,warmup_coverage(),draw)`。该通用所有者按同一声明seek、全树检查，再调用模型池自己的draw一次。MatchModelPool接收返回的PackedStringArray，错误中止准备；其他原void callback继续有效。未与SpellEffectWarmup共享完成位或删除其必要独立上下文绘制。

核对正式UnitModel3D：附属节点挂在模型代理根，bind_model只跟随宿主Skeleton Root的位置；沙盾不创建overlay_material，make_overlay返回原宿主材质，不改next_pass。CPU夹具实际创建Root骨骼并检查位置、原材质身份、一次draw和声明失配时零draw。宿主模型/受击/冻结等原绘制保留。未重跑沙盾或宿主真实渲染，不称完整附属画面验收。

### 固定单Quad beam

beam仍是1×1 Quad、单层无纹理Shader、elapsed/strength普通数值，无晚节点/材质替换。只迁移beam；同provider的zone为PlaneMesh，明确legacy，不顺带推广。

- 旧native预演`.01`缩放且无端点不足以作为合格可见样本。新的provider_sample调用正式set_endpoints：屏幕(280,640)/(440,640)投影到地面后加1世界单位高度；基向量由正式函数设置宽度.5及真实长度，不调用`.01`缩放。`.1`秒strength=1。
- set_endpoints在端点/视线平行时改为将相机横轴投影到端点垂面，必要时用非平行世界轴；不再用可能与along平行的固定RIGHT。零长仍隐藏。这是退化边界修复，没有更换Shader或减少几何。
- 新16项CPU合同通过，目录 `20261018-232903-181590/`；包含两项INF/NAN拒绝、沙盾挂点/原材质/一次draw/错误零draw、beam声明与源审计/实际状态/可见面积、原4年龄状态、strength=0拒绝、零长隐藏、视线平行时basis有限且非退化。实际代表投影边界约160×91.278像素。
- `--family beam`的CPU流程和渲染实验均只调用这16项；沙盾夹具在首帧之前同步释放，没有渲染沙盾。未运行完整SpellWarmupSuite、真实单位组或Main。

### 唯一一次新增渲染与局限

目录 `20261018-233005-458280/`：Godot4.7.1、Apple M5、Compatibility、720×1280、30FPS。顺序为新声明1样本→新建beam用正式set_endpoints/seek在`.1`秒消费→修正相同端点/尺寸的旧4年龄算法→再次新建消费。对照是相同合格可见上下文的旧年龄算法，**不是旧亚像素native setup的性能基线**。

| 单次截点 | 新覆盖 | 正确端点下旧4年龄 |
| --- | ---: | ---: |
| 实际draw | 1 | 4 |
| setup | .264ms | .232ms |
| seek / retain / scan | .002 / .003 / .030ms | .015 / .037 / .058ms |
| frame_post_draw等待累计 | 61.920ms | 99.738ms |
| prepare墙钟 | 62.280ms | 100.155ms |
| retained mesh/material | 2 | 2 |
| 正式新建/load_kind/set_endpoints/seek CPU | .058ms | .072ms |
| 首消费等待截点 | .753ms | 33.982ms |
| 首消费总截点含检查/等待 | .854ms | 34.107ms |

新策略先行，但预先CPU合同已接触资源，后续路径还受进程/驱动缓存与限帧相位影响；不称冷缓存、稳定提速、纯GPU时间或完整游戏帧。首消费是在新实例上调用与MalzaharEffect3D相同的set_endpoints/seek，不运行真实combatant检索、眼睛骨骼或宿主世界。两张`.1`秒消费图字节一致，SHA256 `d36540a35e9ec7eb1b281592b2ff7bd0797790e9fa20eddfaa0147031dc61431`；目视为完整紫色横向beam。PNG最终写出，读回在首用计时之后，后续数字仍可能受扰动。没有移交临时实例池。

监督器总墙钟1.197秒，RSS峰447,315,968字节（426.59MiB），退出0、自有组无残留；20秒/1GiB/30FPS、6秒启动/2秒心跳、ready增长256MiB及整机normal/8GiB启动/4GiB运行余量保护均未放宽。本次无失败渲染或自动重试，也没有重跑沙盾/全场/全库。

### 生成与后续范围

`resources --write`通过，77定义/43provider/90variant，随后工具自检0错误，证据 `resource-artifacts/20261018-233230-988698/`。新门禁执行在生成前后，普通write未更新资格。Python既有资源工具7项通过（坏PCK fixture预期打印FAIL、unittest为OK）；验证路由新资格JSON的1项窄测试通过。代码改变前已查看显式SpellWarmupSuite验证计划；初版计划将新资格JSON标unknown，已接入工具分类和资格测试，没有因此跑重套件。

当前可复用的机制为已资格化的固定无纹理Sphere/Quad状态；新的provider仍须证明生命周期并登记资格。下一批可审查其他固定单层Quad；PlaneMesh需单独几何合同。虚空再生/吸血存在晚可见窗口和宿主overlay，ArrayMesh存在纹理/顶点通道/策略分支，ImmediateMesh/trail、2D/view、ground/screen-depth均暂缓，不以Shader相同放行。模型加工与库存仍未开展。

最终审阅材料位于同一素材库 `effect-coverage/revision-review/`：`core.diff`为本轮继续实施相对开始快照的完整源码/工具/测试及文档差异，`evidence.json`含完整资格记录、实验结果/保护、截图SHA与身份对照，`verify-plan.json`为最终显式窄计划（unknown_paths为空）。两份资格内所有相关源文件的当前SHA均与beam实验开始时一致；实验后只登记资格、更新测试入口/路由及文档，没有重改被测渲染实现。

最终独立 `resources --check` 0错误；项目审计77卡/7023文件/0错误，`git diff --check`及新增Python语法检查通过。与上一轮生成声明对照，90份resources/raw集合全部不变，仅beam的覆盖/setup及zone显式legacy的selection变化；CLPS和其载荷处理未改。没有以完整SpellWarmupSuite/全导出/真实宿主对局作验收，也没有重跑这些重负载。所有动作已确定完成，无拒绝、待批或结果不明事项。


## 2026-10-19：固定采样层候选，未启用

HEAD仍为`f4a0fb79a4b47374653aa28a751899f5dba4c1cb`、main；本批未暂存、commit或push，保留全部前序修改。实施前逐路径SHA/文本、候选增量diff及结果索引在本地`ClashLegends-开发素材库/04-中间产物/构建与验证/effect-coverage/sampled-family/`。

### 代码与资格

- 新候选`sampled_effect_coverage.gd`与开发编译器`sampled_coverage_builder.gd`复用四个正式播放器的现有静态模板协议，不改正式seek、网格/材质工厂、帧数据和粒子池。生成时一次一源扫描，每活跃层记录首个有效帧、最大非退化面积×alpha代表行、源帧/粒子索引、峰粒子数、完整固定uniform/纹理签名、Shader/render_modes、顶点格式/数量；没有逐卡年龄清单。
- 运行候选不完整播放：正式load_kind先准备所有模板，随后每层只建一个临时MeshInstance/私有材质，检查全部活跃层、格式和材质链后实际draw一次。每层身份分别保留，不按相同Shader、RID或普通位置/opacity变化推断新draw。临时节点释放、资源强引用与模板缓存保持；没有全库常驻效果池、全帧数组副本或临时池移交。正式事件创建成本没有因此消失。
- 通用dispatch只在显式`fixed_sampled_layers`时读取已生成selection；当前四provider的原脚本已精确恢复起点SHA，**没有任何正式提供者声明该开关**。所以当前生效规则仍是原legacy，不宣称本批带来实测加载收益。候选执行/编译代码保留供父复核。
- 新资格检查支持该策略，要求原JSON、raw网格、纹理、Shader递归include、候选编译/运行代码全部绑定，完整sample SHA不符拒绝。源码glob补齐gdshaderinc，纳入开发身份；普通write仍不更新资格。新Python窄合同检查include/帧源/网格语义变化在实际generate入口启动引擎前拒绝，遗漏include也拒绝，资格文件字节不变。
- GPU标量uniform传输为float32，候选签名显式比较精确float32规范值；这是数据表示规则，不是像素容差。它仍是待真实后端验证的诊断假设，不能据CPU通过宣称已经解释或修复失败。

### 完整有限迁移矩阵

下表旧draw/临时节点均为**静态推算**：复现原9年龄+逐层首出现补点、逐层私有材质身份新增规则；非真实后端计时。候选每变体一个采样/一次draw仅是尚未启用的契约目标。所有行当前正式状态均为legacy。

| provider | variant | 原采样数 | 原draw静态值 | 原临时节点静态值 | 候选层/临时节点 | 候选draw |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| azir | cast1 | 8 | 2 | 2 | 2 | 1 |
| azir | cast2 | 8 | 2 | 2 | 2 | 1 |
| azir | hit | 6 | 1 | 8 | 4 | 1 |
| azir | spawn | 8 | 4 | 21 | 4 | 1 |
| anivia | storm | 9 | 4 | 235 | 12 | 1 |
| gwen_tristana | rapid | 10 | 6 | 9 | 3 | 1 |
| gwen_tristana | missile | 9 | 3 | 3 | 1 | 1 |
| gwen_tristana | mist | 20 | 19 | 248 | 26 | 1 |
| malzahar | cast | 8 | 1 | 16 | 2 | 1 |
| malzahar | portal_start | 10 | 8 | 46 | 10 | 1 |
| malzahar | portal_end | 8 | 5 | 54 | 6 | 1 |
| 合计，非整场收益 | 11variant | 104 | 55 | 644 | 72 | 11 |

共同规则覆盖普通三角网格/quad、billboard/ray/mesh固定分支和late层；mist的首有效层晚至第45帧，cast首层到31/33帧，均保留。实际shader选择、固定texture能力、blend/cull/depth render_modes、完整材质chain/priority、无skinning的精确vertexformat和首出现分别记录，不以“同shader”删除层。四家族的include含休眠depth sampler，资格只讨论`has_soft=false`分支；没有把深度读取开启的状态套入静态策略。

| 保留类别 | 当前状态与具体原因 |
| --- | --- |
| 沙盾ward、malz R beam | 前批已启用，各上下文原覆盖规则；本批只重跑原32/16 CPU合同，无新画面声明 |
| malzahar spawn | 实际soft/depth层及正式layer_enabled选择，原预演保留；需要真实深度上下文合同 |
| anivia missile | reflection相关能力及弹体消费单独审阅，本批未纳入 |
| 其余sample providers | 没有资格，不自动推广；CPU动态几何/缓存与渲染状态应分别检查 |
| ImmediateMesh/trail、动态geometry | 同RID重建缓冲和首用CPU工作必须保留，需专门协议 |
| 宿主skinning/overlay/next_pass/2D | 格式、链与Canvas上下文不同，本候选明确拒绝 |
| view：lightning/zap、locket、stasis、cask | 原32步保留，未迁移；需按预警/飞行/命中/tail/结束明确所有者，不能本批顺带删等待 |
| ground/corrosion | 原生命周期/晚层/screen-depth路径保留，20步等未变；未作本批优化声明 |

### 实际验证、失败与阻塞

先读显式changed的verify计划（自动16套件及import过宽），实际仅执行小合同、生成门禁和文档审计，未跑整场A/B/C、全库加载或完整SpellWarmupSuite。

- CPU`20261019-045815-762583/`231项通过；增加正式seek代表行/材质独立核对、完整层拒绝后`20261019-045926-721591/`314项通过；候选float32传输规范及关闭正式开关后最终`20261019-050139-744605/`317项通过。只对三个机制代表（azir cast1、anivia storm、gwen mist）实例化有限效果，其余只生成声明；不存在全库实例化。317项中包括原32及16小合同的汇总断言，其内部断言不重复加到317计数。
- 编译阶段两次局部推断错误分别是center与map结果未定类型，明确修复为Vector3/Array后只复验同一小合同；第一次普通沙箱不能读sysctl，在引擎前停止，随后使用相同原保护获准执行。所有失败日志完整保留。
- 唯一真实后端进程`20261019-050001-476789/`：Godot4.7.1/AppleM5/Compatibility，**实际材质签名合同失败**；候选代表及正式复制材质不等于开发工厂签名。未进入render_probe，因此没有新旧代表PNG、没有正式首用与分段wall结果、没有可报告像素等价，也不把headless结果冒充渲染。该失败进程无SCRIPT ERROR/ERROR，检查结果194项且多项失败，整体明确failed。
- 之后请求修正float32规范并恢复真实对照，被自动审批拒绝，理由为“受保护真实渲染流程此前已执行且失败；用户授权明确限制本批最多一次，当前仅凭假设性float32解释再次启动渲染，超出授权的重试范围”。被拒绝的组合shell未执行；之后只单独应用CPU代码并运行headless，未间接绕过拒绝。**进一步真实渲染复验是明确denied，待父任务取得一次针对该失败的明确新授权；不是执行中或结果不明。**
- 无任何代表截图可目视验收；因此四正式provider恢复起点，候选未启用。当前没有代码/旧资源不一致的运行阻塞。下一步先在真实后端保存模板/复制材质的逐字段差异，确认精确原因，再恢复那一个机制代表的独立正式节点同帧对照及有顺序的旧新准备/首用；不能先宣称float32已解释，更不能放宽像素阈值。
- 4项Python资格测试通过（原3+新增1）；新增1同时覆盖include、帧源、网格变更、声明绑定和实际generate前置拒绝。不是7项：中间测试继承误重复运行原3，已整理为4个独立测试。
- 沙盾/beam原资格仅因warmup新增受关闭marker保护的dispatch而显式续记；原成功路径未改，引用最终317中的原32/16 CPU结果，不新增sampled资格，不称新宿主渲染通过。

### 生成、身份与清理

`resources --write`证据`resource-artifacts/20261019-050239-179303/`：77定义/43provider/90variant、build90/reuse87；90清单只是生产器身份更新，selection/resources/raw均与本批起点一致。12模型、74投影、1CLPS全复用，offline worker未启动，没有解析87MB虚空源或重算其CLPS。随后独立check和项目审计见本地evidence索引。最终317 CPU为1.350秒/455,475,200字节峰值，真实失败进程1.592秒/542,294,016字节，清单生成3.526秒/317,128,704字节，均cleanup confirmed；这些不是游戏性能。

收尾：独立resources --check 0错误，项目audit为77卡/7171文件/0错误，diff-check通过；新builder接入既有工具验证路由，最终显式SpellWarmupSuite计划unknown_paths为空，只查看计划，不执行重型suite。本批7个自有进程组最后只读核查均无活PID。

全部引擎仍20秒/1GiB、6秒启动/2秒主线程心跳、ready+256MiB、30FPS，整机normal/启动≥8GiB/运行≥4GiB、只清理自有进程组，未关用户编辑器、未扩限。仅清除本批`/tmp/clash_sample_refine.py`，保留原源件及失败/成功证据。没有commit/push；最终整场profile、view/ground迁移及全项目收尾交回父任务，不能将本批候选当第二阶段完成。


## 2026-10-19：默认值契约修订与第二次审批拒绝

本次仍为同一任务周期，不新建交付记录；新增证据放在`effect-coverage/sampled-family/default-revision/`。修订前完整SHA/文本、pre-render.diff及代码SHA均保留，未覆盖前批记录。HEAD/main不变、未commit/push，四个正式provider仍精确等于最初起点。

### 实质新证据与修订

只读核查Godot官方`a13da4feb`源码，发现Resource._duplicate先枚举property，ShaderMaterial._get_property_list会将未设置的uniform默认值写入param_cache；Dummy的默认值接口恒返空Variant，GLES3返回实际Shader默认值。工厂签名记录在复制前，因此expected里的null与复制后物化的默认值可能不等。原失败并未保存actual，故本记录**没有实测确认所有差异字段或声称根因已由真实日志证明**。源码：[Resource](https://github.com/godotengine/godot/blob/a13da4feb/core/io/resource.cpp#L356)、[ShaderMaterial](https://github.com/godotengine/godot/blob/a13da4feb/scene/resources/material.cpp#L315)、[Dummy](https://github.com/godotengine/godot/blob/a13da4feb/servers/rendering/dummy/storage/material_storage.h#L95)、[GLES3](https://github.com/godotengine/godot/blob/a13da4feb/drivers/gles3/storage/material_storage.cpp#L535)。

此前float32猜测不足：get_shader_parameter读Variant缓存，并不是GPU读回。已**完全撤销标量float32归一**。新契约按类型与var_to_bytes精确编码，纹理按Texture2D类型、类、路径、宽高核对。没有浮点/图像容差。

- 新开发工具`sampled_shader_contract.gd`展开实际shader/include，仅接受反射uniform所需的bool/int/float/vec2/vec3/vec4/mat3/sampler2D窄字面量，未知表达式失败。保存完整引擎版本、源码SHA、render_modes、uniform声明/Shader与Variant类型、准确默认值。它不是通用GLSL解释器，运行不做源码解析或源指纹。
- 工厂生成阶段分别标记override/default，记录有效参数。运行若get_shader_parameter返回null，只能替换为已绑定Shader/引擎的准确默认值；复制后物化的相同值自然匹配，任何其他值仍失败。uniform集合/类型、固定三角网格通道、格式、shader路径、priority及chain检查保留。render_modes和源码内容经独立资格绑定，不以同RID放行。
- 新资格输入加入默认值编译器、纹理存在的.import sidecar，开发inputs也纳入effects/.import。资格记录仍要求原纹理/网格/帧JSON、Shader递归include和消费者；普通write不续记资格。本批没有登记任何sampled新资格。
- 定向真实探针收敛到**只编译azir/cast1两层**，先保存工厂→枚举属性→duplicate逐字段类型、bits和显示值，确认默认物化或override不变后才进入代表图片和正式首用。不会重跑11份声明或三实例。保留原20秒/1GiB/30FPS及全部pressure/headroom/心跳/自有组监督。

### 实际验证

- 首次新默认值CPU合同`20261019-051650-852657/`通过；补齐来源标记与引擎/类型/几何/overlay拒绝后，最终`20261019-051744-362255/`**674项通过**。包含模拟引擎物化准确默认值仍匹配，int非默认及float1e-12变化拒绝，纹理类/路径/尺寸、类型布局、引擎版本、几何通道、overlay/next_pass、priority和实际depth开启拒绝；原正式seek/晚层/结束及primitive/beam CPU小合同继续通过。
- 11variant/72层声明全部按新机制编译；正式实例仍只取前述三个有限机制代表作CPU检查。全部674为外层断言，原32/16内层不重复加计。没有真实画面或新GPU计时。
- 4项Python资格测试通过；新增测试现同时覆盖纹理原件及.import设置变更在实际generate入口启动引擎前拒绝，资格不变；缺shader include拒绝。具体输出在本地证据索引。

### 追加范围、第二次拒绝及状态

父任务基于新源码/CPU证据，在用户已授权“逐步修改与必要受保护验证”范围内明确追加azir/cast1两层一次定向额度。向自动审批提交原始用户授权“授权”、父任务新的两层范围、674项代码证据及原限制未放宽后，相同命令`python3 tools/performance/effect_coverage_probe.py --family sampled --render`仍被拒绝。原始原因完整保留：

> 虽有新的CPU与源码证据，但此前用户限定的本批一次真实渲染额度已使用；本次追加额度仅来自父助手而非用户明确批准，不能扩大原授权范围。

该命令**未执行**，没有新渲染进程、工厂/枚举/复制actual结果、PNG或首用计时；没有换命令、工具或渠道绕过。真实定向复验状态为denied，需要用户明确批准后再由父任务安排；不是pending执行或uncertain。原第一次拒绝记录及全部失败保持原样。

### 资源一致性与后续

独立headless声明生成`resource-artifacts/20261019-051843-778624/`成功，77定义/43provider/90variant，build90/reuse87；模型12、投影74和CLPS全部复用，没有offline worker或87MB源再处理。四provider没有开启新标记，90份selection/resources/raw继续相同，只更新生产器身份。资源check0错误，具体wall/RSS、审计/diff/源身份及自有组清理写入本地evidence。

本批可交付的是更准确的默认值契约、CPU拒绝合同及狭窄诊断探针。真实物化差异、图片等价和首用仍**未验证**，不能将674CPU、72层数据或源码推导写成全部GPU通过。不做view/ground、不启用四provider、不commit/push。
