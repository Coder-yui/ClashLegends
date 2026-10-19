# 预加载重构第一阶段：开发生成产物与运行依赖

本页保留本阶段当时的过程、失败和验证身份；五阶段当前状态及待修问题统一见[静态收口审查](2026-10-18_preload_mechanism_analysis.md#2026-10-19静态收口审查当前)。阶段内“尚未开始/无拒绝”等只描述该次执行，不代表后续全任务状态。

## 当前结果

第一阶段已实施，停在本地复核。全库 **77 定义、43 provider、90 variant** 均生成独立版本化依赖清单。运行的 `EffectResourceManifest.files()` 不再解析来源 JSON、遍历发射器发现依赖或计算源 SHA；CLPS 不再打开其可编辑源件。源、层筛选、Shader 路由与生成器的完整内容身份由开发/构建门禁检查；缺产物/坏格式不回退大 JSON。载荷 SHA 仍在运行检查。

窄验证已通过；**实际加载收益未测**。没有启动 A/B/C、全库渲染压力、第二阶段 PrimitiveMesh 实验、完整游戏导出或发布冒烟，没有改采样/绘制次数、库存、模型/动画所有权、Standard/Fast 选项，也没有 commit/push。编辑器真实 F5/F6 按钮和完整游戏 PCK 尚未实操；新增门禁代码、调用关系及微型原生 PCK 已验证，不把它们称作完整发布验收。

操作与新卡规则以[资源生成流程](../RESOURCE_ARTIFACTS.md)为准。审阅证据在本机开发素材库 `04-中间产物/构建与验证/resource-artifacts/phase1-review/`：`evidence.json`、`migration.tsv`、`production-and-tools.diff`、`workspace-identity.json`；原始生成与微型合同目录均保留。

## 2026-10-18：实现边界

基线 HEAD 为 `f4a0fb79a4b47374653aa28a751899f5dba4c1cb`，分支 `main`。开始时已有的 retained 身份集合去重、测量工具、两份分析/基线报告及 UID 保留。生产新改动集中在 `effect_resource_manifest.gd`、`compact_particle_samples.gd`、虚空召唤 provider；`spell_effect_warmup.gd`、`battle_presentation_3d.gd` 的已有修改不属于本阶段。

1. 新生成流程：`tools/dev.py resources --write/--check`。Python 对所有 sampled 数据做只省略数值 frames 的投影，Godot 只编译定义并执行原依赖遍历、层/系统筛选及 Shader 策略，不实例化播放器。每个 provider/variant 保持独立身份。
2. 新清单：schema=1、generator=`effect-artifacts-v1`、policy=`effect-files-v1`，包含来源内容 SHA、策略输入摘要、筛选声明与真实运行 ResourceLoader/raw 文件。90 个清单共 169,745 字节；含清单本身的 runtime raw 集合为 324 个路径。这是文件/声明静态计数，非引擎加载性能。
3. 开发索引：`tools/generated/effect_artifacts.json` 记录输入和产物精确 SHA、覆盖数及紧凑数据等价结果。check 重新读取完整输入内容和路径集合，不用 mtime、无失效摘要缓存或单纯“上次成功”。同一内容输入及产物复用生成时的位等价结果；不把全库校验放进导出游戏。
4. 运行消费者：按键读取一个小产物，保留长度、schema/生成器/策略/身份、数组和路径检查；未知/缺失/损坏明确准备失败。没有新增常驻全库缓存。`resolve()` 仍为预热声明服务，未改变采样契约。
5. 源件与格式：虚空召唤原 86,756,851 字节 sampled JSON 原样移到受版本控制的 `tools/source_assets/void_summoning/`，作为可复现生成工具输入，明确排除导出；不是删掉源或转为仅本机不可恢复文件。移前后 SHA 均为 `9050c08ed2270798d942bfbd2c41b484810e14b5db13de7a4cde9689d2f02abe`。CLPS 升至 `CLPS0002`/schema2/`compact-f64-v2`，源路径身份与头更新，**原压缩载荷字节完全相同**。不兼容旧格式。
6. 发布保障：现有本机导出只有构建时文件 SHA 和临时签名，没有证明运行包/更新链对每次原始载荷读取有等价完整性保障，因此没有删除或缓存载荷 SHA。长度、整数维度、最大分配、解压长度、offset 端点/单调范围与帧/层/行边界保留并补足类型拒绝。
7. 实际门禁：编辑器 `_build()` 在 F5/F6 前执行 check 并以 false 中止，插件排除导出；正式 `dev.py workbench` 启动前也执行 check；相关 verify 风险计划纳入 check；既有 `export_macos.py` 在引擎导入/导出前执行 check，导出后、冒烟前审计原生 PCK 的路径与字节。裸 Godot Export/CLI 不作为受验证发布入口，文档明确该边界。没有新增 CI、账号或发布动作。

## 迁移覆盖与等价证据

| 范围 | 已完成 | 明确保留/未覆盖 |
| --- | --- | --- |
| 77 个编译定义的 90 声明变体 | 独立清单、按真实层/系统/Shader 策略生成；逐项见 migration.tsv | 不自动猜测未声明的动态效果；新卡必须声明 provider/variant |
| 旧22份依赖头 | 全部删除；新生成投影与 HEAD 中22份旧头的完整元数据、源 SHA 分别一致 | 无旧头兼容、失配回退 |
| 依赖集合 | 90份持久化资源/raw 集合与生成时原遍历输出逐项集合相等；只排序去重，不合并不同变体 | 该比较是依赖/序列化合同，不是全库引擎预热；旧头和虚空源件的退出是有意变更，清单自身加入 raw |
| 虚空召唤 | 441,667 行、16,341,679 个 float64 位等价；961帧/20层/宽38；载荷134,420,536字节，CLPS10,522,360字节 | 运行仍解压和计算载荷 SHA，未测其实际耗时 |
| 其他采样/网格/系统 JSON | 仍由播放器读取的文件继续出现在 runtime raw 和导出 include_filter | 未全部转换为二进制；不得误删为“源件” |
| 模型、动画、音频、纹理 | 本阶段只保留原资源闭包 | 未做确定性模型加工迁移、动画所有权或状态覆盖改造 |
| 开发与发布 | 生成/check/verify/编辑器运行前/正式导出前均有调用；原生收录检查已接入发布工具 | 完整发布包本次未生成，编辑器按钮未人工实操；直接原生 Export 不执行项目发布包装器 |

原遍历保留在开发专用 `effect_manifest_builder.gd`，`_collect_files` 与 `_collect_shaders` 从旧实现原样迁出；JSON 输入换为经完整内容验证的元数据投影。数值 frames 不可能含资源路径，非数值/非有限帧会在 Python 拒绝；其他小 JSON 保持同一完整读取，筛选由同一 provider/player 执行。由此保留依赖集合，不以同源文件缓存混并各 variant。

## 验证命令与结果

- `python3 tools/dev.py verify --plan --changed ...`：先审阅自动计划；插件注册/项目配置触及共享入口使自动范围过广，因此显式 `--suite DependencyHeaderSuite --changed ...` 保存窄计划，没有执行计划中无关的全套导入和领域套件。实际 GDScript 合同由下面受保护入口执行。
- `python3 tools/dev.py resources --write`：最终生成成功，77/43/90，随后自动 check 0错误。最终证据目录 `20261018-223403-244453/`。
- `python3 tools/dev.py resources --check`：最终内容身份/导出过滤检查通过；源/层/Shader/新增文件以及产物变化的拒绝用临时 Python 夹具验证，同尺寸且恢复 mtime 的源变化仍失败。
- Python 定向单测：`test_effect_dependencies.py` 2项、`test_compact_samples.py` 6项、`test_resource_artifacts.py` 6项、`test_verify.py` 39项通过，合计53项。覆盖位等价、损坏格式、源失效、原生PCK丢件/错字节/误含源件，以及真实发布入口 check 失败时不启动引擎。test_verify 中 fixture 的预期 FAIL 日志不是整体失败，最终 unittest 为 OK。
- `python3 tools/maintenance/resource_contracts.py`：最终37项微型格式合同全过；单独隔离 PCK 中 `editable_source_absent=true`、CLPS与小清单可消费，错误为空。PCK 仅含微型夹具和消费者，无源工程文件系统回退路径；它不是完整游戏包。目录 `contracts-20261018-223442-039364/`。
- 所有实际引擎声明/合同进程均沿用 safe_probe 的单进程20秒/1GiB、30FPS、6秒启动/2秒主线程心跳、ready增长256MiB及自身组清理，并叠加整机 normal、启动可用≥8GiB、运行≥4GiB；未扩大阈值、未触碰用户编辑器、未改系统设置。最终 guard 的内存/时长/cleanup 原始数值见 evidence.json，不当作游戏性能。
- Python语法检查、项目审计与 `git diff --check` 通过。未目视渲染、试听、联网、首用或整场性能验收；本阶段没有改变美术输出和采样。

保留失败过程：首次普通沙箱调用在 sysctl 预检失败、未启动引擎，CLPS已在此前离线生成；随后通过工具审批使用相同保护成功。首次微型合同33项中5项发现异型字段比较异常，已改为先验类型并复验；坏JSON用无引擎错误日志的 parser 拒绝。一次 Python ZSTD 测试暴露不支持的 max_output_size 参数，改为标准库有界 Decompressor 并通过最终6项。旧verify预期路由断言随新门禁更新后39项通过。所有失败日志未删，当前无被拒绝、待批准或结果不明的操作。

## 后续边界

本阶段到此停下供复核，收益为**未测**，不引用旧虚空局部274ms作为整场收益。复核后若需性能验证，先一个受保护新进程，只量单个代表请求 `files()`/CLPS读取段并观察源路径确实未打开；再由父任务决定是否需要一次已有轻量固定对局配置检查首次事件与内存。不得自动扩成 A/B/C 或全库压力，也不通过缩小库存/采样掩盖首用卡顿。

第二阶段仅保留文档计划：选一个简单 PrimitiveMesh 效果，列真实渲染状态与单纯年龄/位置/透明度变化，再设计状态覆盖对比。尚未运行、合帧或删减任何采样。

## 2026-10-18：独立复核后的窄收尾

- 输入闭包：逐项阅读声明、层/系统筛选、Shader 路由及其数据辅助方法，没有发现影响当前清单计算却漏出 inputs() 的场景/材质/导入输入。瑟提场景只返回路径；潘森GLB/纹理虽由脚本常量preload，但声明未读其内容，实际系统/层选择来自已经覆盖的integration.json、systems.json和脚本。金克丝/飞机投影辅助只读已覆盖的geometry.gd。未盲目加入`.tscn/.tres/.res`、`.import`或全仓库资源hash，未改生成器/索引/90清单，未重新生成或运行Godot。
- 发布包装器：将PCK审计抛出的ValueError纳入既有报告异常处理，原错误字符串继续写入result.json，返回失败，不执行签名/冒烟，不回退或再次导出。
- 窄验证：先审阅显式DependencyHeaderSuite的verify --plan，仅实际执行`python3 -m unittest discover -s tools/maintenance -p 'test_resource_artifacts.py' -k release_bad_pck`，1项通过。该测试mock引擎/导入/导出，在临时目录写4字节坏包，实际调用pck_audit并断言返回1、result.json的原错误`Not a standalone native PCK`、passed=false、只有import/export两步和前后身份字段。输出中的FAIL是预期坏包报告，不是unittest失败。没有完整导出、引擎进程或重跑原53项/37项合同。
- 恢复与成本：资源流程补充“修正报错原因 → resources --write → resources --check”；write完整覆盖期望产物、清孤儿并最后写索引，部分产物/索引不一致由现有check合同拒绝，不引入事务框架。F5/F6每次同步扫描797输入约225.7MB，加清单/CLPS约236.4MB内容及元数据操作；这是开发门禁，真实等待未测，不能宣称开发启动整体变快，导出游戏零次全源hash。
- 本次只修改发布脚本、其窄测试和两份文档；没有改用户资源。第二阶段尚未开始；仍未commit/push。完整窄收尾diff和mock结果见同一素材库`phase1-review/closeout/`。
