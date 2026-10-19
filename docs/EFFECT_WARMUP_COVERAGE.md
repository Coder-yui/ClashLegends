# 效果预热覆盖契约

`SpellEffectWarmup` 的效果采样入口目前只有**沙盾 ward、蚂蚱 R beam**迁移到声明式状态覆盖。沙盾模型附属入口复用同一声明、各上下文各绘制一次；其他效果和view/ground保持原算法，本页不表示全库已优化。源件/依赖的开发生成流程见[资源生成流程](RESOURCE_ARTIFACTS.md)，本轮证据见[第二阶段记录](deliveries/2026-10-18_preload_effect_coverage.md)。

## 所有者与策略

提供者在 `resource_manifest(variant).sample.coverage` 声明策略；通用实现位于 [EffectWarmupCoverage](../scripts/presentation/effect_warmup_coverage.gd)。执行器不认识卡牌名称，不根据同 Shader 路径或 RID 猜测等价。

- `static-untextured-primitives-v1`（version=1）：仅审阅过的固定 SphereMesh/QuadMesh，无蒙皮、动态几何、纹理、screen/depth 采样、overlay、next_pass、2D；Shader 只有普通 float uniform。每个样本指定年龄和应出现的完整状态，各状态声明数量、几何参数、Shader、uniform 和 render_mode。
- `legacy-age-identity-v1`：明确保留原算法。**迁移期未声明 coverage 的旧提供者统一使用这一受审保守策略**，报告以该策略名标记；不静默启用状态缩减。它仍可能多做工作，也不是已经证明完备。未知策略、坏版本、空状态、漏采样声明及实际资源不符均失败，不退回 legacy。新提供者暂不能证明覆盖时，应显式声明该 legacy 策略并登记证据缺口。

声明只减少采样/扫描/绘制工作，不转移实例池所有权。预热结束仍销毁临时节点，保留其网格/材质资源；正式消费重新构造实例。不能把这项改造说成“实战池已预建”或“所有硬件首用无卡顿”。

## 沙盾的覆盖证据与边界

`configure()` 一次创建球壳和全部24个沙粒；没有后续增删节点或替换 mesh/material。`seek()` 在 0≤age<2 时显示，在2秒隐藏；真实消费走 `configure / bind_model / advance_status`，以状态移除或暂时隐藏控制显示。绑定只改变挂点，没有附加模型材质链。

| 状态 | 真实几何和通道 | 材质与上下文 | 生命周期变化 |
| --- | --- | --- | --- |
| shell ×1 | SphereMesh，radius=.7/height=2.5/64段/32环；vertex、normal、tangent、UV、index；无颜色、UV2、bones/weights | shell.gdshader；unshaded、blend_add、cull_back、depth_draw_never、shadows_disabled；普通float elapsed；无纹理/屏幕/深度输入 | scale、elapsed改变；rim/bands/gain是同一Shader数值计算，无材质/几何分支切换 |
| grain ×24 | QuadMesh，.06×.09，Z朝向；相同通道；无蒙皮 | sand.gdshader；同上但cull_disabled；普通float opacity；无纹理/屏幕/深度输入；vertex内相机billboard | 位置与opacity改变；24份私有mesh/material仍全部创建和保留，身份差异不产生新覆盖样本 |

`.08` 秒全部25个几何可见且alpha非零，两种状态同帧真实绘制。0/.38/1.999及原7年龄的结构合同检查用于证明没有漏晚层；结束/暂时隐藏没有新资源，不需要为消失再绘制一遍。旧默认年龄 `.025,.05,.1,.2,.4,.8,1.5` 改为只 seek/检查/retain/draw 一次；不是把7次等待合并后仍做7次CPU扫描。

运行对所有实际几何检查固定类/参数/顶点通道、无skin/骨架、无overlay/next_pass、Shader身份与float参数、有限uniform值及声明的样本值域、非退化有限全局变换、优先级、阴影策略、数量和可见性。float类型本身不表示语义安全，资格仍依赖源码审阅。开发生成还核对源Shader的render_mode/uniform，拒绝采样器、include、instance uniform和screen/depth入口；源码完整身份由现有生成门禁跟踪。**这些检查不是对任意Shader的自动语义证明**；新增分支、变更生命周期或Shader内容仍须人工审阅及必要首用验证。

模型池调用沙盾 `prepare_resource_sample()`，现改为 `EffectWarmupCoverage.prepare_attached()` 读取同一份coverage，检查后由模型池callback绘制一次。独立效果入口和模型附属上下文各自保留一次绘制，不共享完成位。沙盾只跟随Skeleton Root位置，`make_overlay()`返回原宿主材质，不添加链；16项窄合同检查挂点、原材质身份、一次draw与错误时零draw。MatchModelPool接收返回错误并中止准备，旧void callback继续有效。未重跑宿主实际渲染或整场；其余宿主模型/状态绘制保持。

## 覆盖审阅资格与失效

开发资格独立保存在 `tools/maintenance/effect_coverage_reviews.json`，检查器为 `coverage_reviews.py`；普通 `resources --write` **不修改该文件**。当前只有两份资格，分别绑定11/7个相关源码内容SHA及完整sample声明SHA。共享覆盖器/执行器、provider和Shader是必要输入；沙盾另绑定附属/宿主所有者及场景，beam绑定正式消费者和投影辅助。无关卡牌/Shader修改不要求重新认可这两份资格；普通依赖门禁仍按其既有范围运行。

`--write` 在CLPS加工和引擎启动之前先检查登记输入；变更失败需审阅、必要的窄验证，然后显式修改对应资格SHA/证据。声明收集后、发布生成清单前再次要求每个static策略都有资格，完整sample匹配，player/Shader纳入输入；`--check`也检查同一资格。资格文件不进入运行包，不新增运行源码hash，也不创建审批服务。

这解决“晚时刻新增节点、uniform名单不变却改Shader语义后，重生成自动认可旧coverage”的缺口：即使改动不在代表年龄出现，源码内容已与独立记录不符，write不能放行。**资格记录是开发者对具体内容的显式审阅证据，仍不是连续时间自动证明**。手工更新记录必须说明审阅/验证和局限，不能只是照抄新hash绕过错误。当前沙盾仅引用已有独立效果渲染和新的CPU附属合同，未伪称重验宿主画面。

## 固定单Quad：蚂蚱 R beam

beam的Quad为1×1，顶点/法线/切线/UV/index固定，Shader无纹理，只有elapsed/strength；blend_add、cull_disabled、depth_draw_never、shadows_disabled、fog_disabled。后续调用 `set_endpoints / seek` 只更新位置/基向量和普通数值，没有新增层或材质。代表`.1`秒strength=1，并声明样本strength值域[.1,1]。

旧预演 `.01` native缩放且无端点不适合作为合格可见样本。新的 `provider_sample` setup调用与正式消费者相同的 `set_endpoints()`：用屏幕(280,640)/(440,640)投影到地面后加1世界单位高度；不调用`.01`缩放。原单位Quad由正式接口设置宽度.5、长度及方向，当前单实验投影约160×91像素。视线与端点平行时投影相机横轴、再用非平行轴兜底，避免固定RIGHT与along平行导致basis退化；零长度仍隐藏。zone仍使用legacy，PlaneMesh未迁移。

本轮只渲染beam一次，先新1样本及新建消费，再以修正端点尺寸的旧4年龄作参照。不是旧亚像素setup的性能基线，也不是冷缓存/整场验证。首用仍重建mesh/material；没有移交临时实例池。

## 新提供者接入

1. 先列完整生命周期中的几何/材质创建、首次可见和替换时机，区分数值变化与新状态。声明每种真正要绘制的状态；一个时刻可覆盖多个状态，不以粒子序号或私有材质ID重复记账。
2. 符合上述窄边界才用static策略；固定网格的不同顶点格式、多遍、蒙皮、动态trail/ImmediateMesh、2D/view/ground、screen/depth必须另立有证据的机制契约。不能只把类名换成ArrayMesh绕过边界。
3. 在provider返回coverage，确保每个状态至少被一个可见样本覆盖。实际检查不符令准备失败，不自动降级。未审阅类别显式选legacy并记录缺口。static声明需独立审阅资格，不能靠重生成自动认可。
4. 相关内容变更先审阅/窄验证并显式更新相应资格，然后执行 `python3 tools/dev.py resources --write` 和 `--check`；覆盖声明进入生成清单的selection，源策略变化使门禁失效。运行不读取Shader源码、不计算源指纹。
5. 先窄结构/拒绝合同，再受保护单provider实际绘制及新建正式实例首用。报告帧等待含自然绘制、同步和限帧，不是纯GPU时间；单次有顺序诊断不能宣称稳定提速。监督入口见[性能工具](../tools/performance/README.md#单效果状态覆盖原型)。


## 固定采样层候选（未启用）

`sampled-fixed-layers-v1` 的候选实现位于 `sampled_effect_coverage.gd`，开发扫描位于 `sampled_coverage_builder.gd`。当前**没有正式提供者声明 `fixed_sampled_layers=true`**，所有 sampled 仍用旧算法。CPU 数据合同已通过。新增azir/cast1两层真实复验确认默认参数枚举/复制后的精确签名匹配，但同帧代表对照因诊断视口空世界报错而整体失败；诊断修复后只有9项headless世界隔离合同，尚无修复后真实图像证明，不能称为完成迁移。详细矩阵、失败及恢复边界见[本轮记录](deliveries/2026-10-18_preload_effect_coverage.md#2026-10-19固定采样层候选未启用)。

候选接入协议限定为已有 `load_kind/_data/_materials/_meshes/shape_basis_for/layer_enabled` 的固定采样模板家族：全部活跃层无 trail、实际 soft-depth、distortion、蒙皮、多遍或动态网格；顶点格式精确为非索引三角形 position/color/UV。源 Shader 可以声明休眠 depth sampler，但 `has_soft=false` 的固定分支必须经审阅绑定，不将真实 screen/depth 路径纳入此资格。不同 Shader/render_mode、网格源/格式、所有固定 uniform、纹理引用、billboard/mesh 分支和层身份分别保留，绝不按同 Shader 或 RID 合并。

生成期逐源扫描真实粒子帧，记录每层首个有效帧、非退化代表行及模板材质签名。只把每层一行和状态元数据写入覆盖声明，不复制完整帧。运行候选先调用正式 `load_kind` 以保留全部网格/材质模板 CPU 准备，再建每层一个临时代表、检查完整层集合、保留资源并绘制一次。正式粒子池没有移交或减少；首次正式实例仍需复制自己的粒子材质。该区分不能被省略为“首用零分配”。

如后续获准复验并完成真实后端合同与画面验证，新 provider 才可显式设置 `sample.fixed_sampled_layers=true`，并登记独立审阅资格。生成器从 `json[0]` 编译覆盖，运行读取同 provider/variant 的生成 selection；未知/缺失/漏层或材质不符立即失败，不降级。审阅同时绑定播放器、原帧 JSON、网格/纹理、Shader 及递归 include、生成器和运行消费代码。普通 `resources --write` 不写审阅记录，源码、include 或样本声明变化仍使资格失效。


### 默认 uniform 契约修订（仍未启用）

固定层候选现已撤销float32归一。`sampled_shader_contract.gd`只在开发期展开绑定的Shader/include，并用窄字面量语法读取反射到的uniform默认值；不支持的表达式直接失败，不猜测。契约记录引擎完整版本、Shader及include内容SHA、render_modes、uniform的Shader类型/Variant类型/声明、默认值及工厂显式override来源。运行不读源码或计算源SHA；参数按Variant类型及`var_to_bytes`精确编码，Texture2D另比较类、路径和尺寸。

原工厂未设置的uniform代表**该版本Shader的准确默认值**。复制材质后若引擎物化同一默认值仍匹配；任何其他非默认值（包括1e-12）拒绝，不将null当通配符。显式override与Shader默认值在生成契约中分别标记。纹理原件及存在的.import配置加入资格必需输入，开发全局身份亦纳入effects/.import；不从.godot导入缓存建立可移植资格。

674项CPU合同通过，覆盖模拟默认值物化、非默认值拒绝、纹理/类型/引擎/几何/覆层/priority变化。该结果不能替代真实后端。历史审批拒绝保留在阶段记录。用户新增授权的一次azir/cast1两层真实复验现已执行：两层实际factory→枚举→duplicate默认物化及完整签名匹配；正式首用两图相同，但同帧分层代表对照因SubViewport.world_3d为null报错，外层guard明确失败。诊断入口已改显式独立World3D，9项headless合同通过；未追加真实运行，因此没有修复后的同帧代表图或新资格/正式provider启用。内层134项passed不能覆盖脚本错误；当前状态见[最终收尾](deliveries/2026-10-18_preload_mechanism_analysis.md#2026-10-19授权后的最终收尾)。
