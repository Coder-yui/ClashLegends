# 预加载第三阶段：模型模板、一次动画所有权与可达材质

## 当前结果

已接入一次实例动画所有权、12份只读模型模板与严格match材质闭包；覆盖剑魔、太阳圆盘、奥恩、卑尔维斯、赛恩、两种虚空鱼、虚空之门、牧魂人、天使近远程及纳尔大小形态。已准备库存的合法候选切换/挂接/回收有窄验证；库存miss、新owner和动态特效分配另计。

终极剑魔首轮15像素差异及取景缺失保留为历史失败，后续完整取景三图严格相同。Pantheon候选死亡姿态仍差14像素，已撤回候选、恢复原加工；其场景后续仅新增库存构造元数据。历史材质“完成”表述曾被撤回，当前严格修订及证据见后文。不得将旧首批的“模板未生成/阶段4未开始”读成当前状态。

**整场加载/RSS/首用收益未测，第三阶段并非所有模型都已迁移。** 库存后续已另行修订；五阶段矩阵与本轮静态发现统一见[收口审查](2026-10-18_preload_mechanism_analysis.md#2026-10-19静态收口审查当前)。本页以下按时间保留过程和原始证据，未commit/push。

## 2026-10-18：实现与迁移

开始HEAD为`f4a0fb79a4b47374653aa28a751899f5dba4c1cb`，分支main。阶段1/2已存在清单、CLPS、源码资格、retained诊断等未提交修改；本批只在其上追加。初始完整路径内容SHA与status保存在开发素材库`04-中间产物/构建与验证/model-ownership/batch1/`。

| 范围 | 本批结果 | 仍保留的运行成本/边界 |
| --- | --- | --- |
| 通用动画所有权 | ModelAnimationInstance根节点记录；包装器、摄影、ModelVisualResources、池创建、展示样本及分步bind移交同一记录；未知记录/版本/根身份、外部替换库明确拒绝 | 每活体仍创建独立AnimationLibrary/Animation；普通无脚本场景按allowed裁clip，未迁移脚本明确legacy-script-unfiltered-v1 |
| 剑魔normal/ultimate | 开发模板：20个当前卡牌全部形态所需clip、full/normal/wing三网格；源根高度轨道和Passive_Attack_Ult已前移，包装器与bind不再各复制一次 | 原GLB仍是场景依赖，不能宣称完整导入动画不驻留；每实例独立weapon_snap/骨骼/播放器；每次动作通知只选网格，不再扫描所有权 |
| 太阳圆盘blue/red | 开发模板：6个clip；Attack1/2两骨骼遮罩前移，删除每次prepare深复制及裁轨道；直接摄影也同步准备一次 | 废墟朝向、死亡显隐及projectile anchor仍属实例状态；本次只运行蓝方最小合同，红方静态审计同脚本/同圆盘模板，废墟资源不同 |
| 开发生成/门禁 | 同一个resources --write调用model_template_builder；同effect_artifacts索引记录源/配方/产物身份及clip/mesh迁移表；source目录GLB/纹理/.import和project.godot纳入输入；缺失/修改/孤儿.res拒绝 | 依赖Godot编辑器先完成源导入；source_md5和缓存存在检查拒绝旧源缓存；主GLB导入参数变更须重导入并明确审阅配方SHA，write不自动更新 |
| 池创建/回收/补货 | 普通创建和sample factory设置defer_animation_ownership；同步bind或单clip step_bind完成才移交；错误传出prepare/refill/take，UnitModel3D显式失败 | 未改变容量、初始数量、慢实例判定或补货阈值；新契约不等于已允许这些模型在局中轻量补货 |
| 材质 | 原有快照和实例材质行为保留 | 本批没有删隐身/freeze候选；不可达材质削减留后批，不能称已完成 |

动画复制实现从ModelVisualResources原样移到model_animation_copy.gd，通过原静态API转发，数值copy_track与扩展资源保真分支未改。共享模板只读属于代码契约；Animation资源没有语言级冻结，需用两实例及模板隔离合同维护。记录只持有根WeakRef，避免根元数据与RefCounted强引用环；库/动画按实际对象引用保存，重复显式bind验证身份，不在每次动作播放时遍历。

脚本、摄影、模型预览、封面、UnitModel3D普通/死后模型、prepare/take/refill已静态逐项审计。未来新卡通过配方与visual_animation_contract声明，不增加中央英雄分支。现有clip收集按所有已声明形态闭包，摄影需要额外片段时在extra_clips声明；不能仅用当前形态裁掉后续变身所需动作。完整调用方检索见证据callers.txt。

## 定向验证与限制

- 先审阅verify --plan（自动16套件过宽且新工具需明确范围），再保存显式LoadingAssetsSuite计划；实际只执行此处列出的小合同与工具检查，没有执行计划中宽泛import/完整suite。
- `model_contracts.py`最终CPU目录`20261019-000304-329338/`：35项通过。每次最多两活体模型，先剑魔后圆盘；摄影直wrapper、重复prepare/bind不复制、同步/分步20和6次clip步骤、单实例loop/key/动作/骨骼不污染另一实例与模板、normal→ultimate→revert、modifier实例独立、正式recycle/take及圆盘死亡可见性复位、普通场景clip别名/源保留、未知记录和外部替换库拒绝。未模拟完整战斗控制/复制链或实际整场补货调度。
- CPU前期失败包括：新增错误传播误用void返回于bool函数（已修）、探针自身未显式声明take返回类型、误写不存在的acquire接口、把Godot自动PhysicalBoneSimulator也计入唯一脚本modifier。生产错误和探针错误均保留日志，没有伪称首次即通过。最后仅受影响窄合同复验。
- 实际渲染目录`20261018-235834-381776/`：Godot4.7.1/Apple M5/Compatibility，720×1280，30FPS。生成路径与独立重述旧深复制/高度/遮罩/网格表达式对照；全部保留clip的长度、loop、track类型/path/插值、key数量/时刻/值/transition相等。普通剑魔、圆盘Attack1_BASE/Death像素相同；终极Passive_Attack_Ult有15/921600像素差异，bbox=(274,463)-(312,480)，RGB最大差40/84/82；严格探针passed=false，非引擎异常。目视未见动作/部件变化，稀疏差异仍留父任务复核；不改探针阈值掩盖失败，不继续盲重跑摄影。首次构图不充分的原图及两次渲染失败过程均保留。
- 当前CPU较渲染后唯一生产改动是set_visual_clip不再调用所有权扫描，只初始化模板后选择同一网格；35项CPU已针对新路径复验，旧渲染不是改后再次执行的结果。
- 沙盾覆盖资格：本批改了被pin的match_model_pool/model_visual_resources/unit_model_3d，write按预期拒绝。核对diff仅涉及动画所有权/错误传播，沙盾sample/geometry/shader/overlay/draw callback未改；在`effect-coverage/20261018-234939-572587/`执行32项CPU合同通过后，明确更新这三项pin并追加证据/限制。beam资格无变化。未盲更新资格，未重渲染沙盾宿主。
- Python资源工具9项通过（包含同尺寸恢复mtime的模型源/设置/产物变化、孤儿、旧导入缓存、未审阅导入参数的拒绝）；verify工具40项通过。fixture中的FAIL日志为预期失败路径，unittest最终OK。项目audit 77卡/0错误及diff检查通过；最终文档审计见收尾。
- 所有Godot进程沿用单进程20秒/1GiB、6秒启动/2秒主线程心跳、30FPS、ready+256MiB和自有组清理，启动normal且可用≥8GiB、运行≥4GiB；未放宽阈值。最终CPU约0.6秒/RSS245MiB以内（准确原值见guard），清理confirmed；不是游戏性能。

## 剩余迁移与真实约束

| 未迁移项 | 当前剩余工作 | 下一批必须解决的约束 |
| --- | --- | --- |
| VoidGate | 每实例合成绝对Spit、延长Death；保留原始Spit delta供运行Idle+Spit叠加 | 开发模板需同时暴露只读delta与绝对clip；运行独立Skeleton与idle_age不能烘掉；当前首批操作集未实现加法合成 |
| Yorick | 每实例披风拆面、IdleIn裁1s；创建材质和modifier | body/cape须保留Skin/transform/骨骼路径/排除闪白；随机UV、age、两层shader和modifier仍每实例独立，不能把当前_cape_materials共享 |
| Gnar | 每实例按surface/bone过滤三角、合成加法缩放动画 | 多种导出参数、blend shape/权重、插值时间并集及scale override须完整进入配方；首批仅整surface过滤不能直接替代 |
| Kayle | 每实例过滤mesh/换纹理/接强化shader | 可前移几何；rage strength/elapsed、材质next_pass和动态强化uniform必须实例独立，先拆静态材质模板与活体状态 |
| Belveth | 每实例去HEAD、body纹理替换和材质复制 | 无已知不可迁移障碍；待补静态材质替换操作与两实例/首次形态窄合同，未为赶范围盲套 |
| Ornn | 每实例复制mesh后surface_remove | 原路径保留LOD/阴影等网格信息；首批重建surface语义不能不经审阅替代它，需明确保留策略 |
| Sion | 每实例生成unarmed网格 | 几何可前移；berserk/Death/Passive_Death第23帧选择仍运行独立，需覆盖死后复生及回池 |
| Voidfish两种 | 每实例按_hidden_surface筛选mesh | 变体输出与源Skin/材质须区分；部署遮罩、粒子/时钟仍运行状态，不得合并删掉 |
| 其他script包装 | legacy全clip及其自有准备仍保留 | 逐类声明实际clip/状态所有权；未迁移不表示已证明必须全库复制 |
| 隐身/freeze候选 | ModelVisualResources仍无条件创建ghost与普通frozen候选 | 需要在根创建之前得到本局能力/目标状态闭包，包含后续形态/复制/控制；本批不改库存，后批最小接口不能仅看当前形态 |

若复核接受本批，先处理上表同机制静态几何/动画，不同时全面改材质与库存。性能归因最多另提一个受保护单模型、同数实例、只量instantiate/wrapper/bind段的小采样计划；本批尚未执行，不引用旧全场动画段当收益。

## 2026-10-19：首批收尾状态

- 最终resources --write目录resource-artifacts/20261019-000606-750519/，77定义/43provider/90variant和两模型模板成功；随后独立resources --check为0错误。两次相同配方加工输出.res字节SHA完全相同：剑魔1,790,841字节，圆盘35,236字节。源GLB分别声明97和6个动画，活体闭包分别为20和6；不能将源GLB文件级驻留当作已经删除。
- 最终生成监督3.707秒、RSS峰362,266,624字节；CPU合同0.611秒、RSS峰245,153,792字节；渲染1.589秒、RSS峰352,616,448字节。三次自有组清理均confirmed、无残留PID。渲染exit1源于严格像素比较，安全监督没有内存/心跳超限；这些均是验证进程数值，不是运行加载收益。
- 最终生成曾在启动前因可用内存不足停止，确认未启动引擎；稍后只读新证据normal/51%约8.16GiB，满足原≥8GiB门槛后仅重试一次成功，运行health保持normal且约8GiB可用。没有放宽保护或停止用户进程。首次普通沙箱沙盾CPU入口sysctl读取失败未启动引擎，之后相同保护审批执行；未遇自动审批拒绝。
- 最终项目audit为77卡/7035文件/0错误，diff --check通过。工具单测9+40项通过，不重跑已无改动的CLPS/全部效果单测。正式场景蓝/红、normal/ultimate已静态审计；实际CPU/渲染边界和未覆盖项仍以上文为准。
- 核心完整增量diff为本机batch1/core.incremental.diff（约69KB），包含生产、配方、生成工具、窄合同、资格续记；13个已有文件的阶段开始基线均用SHA核对，资格文件也单独重建核对，避免把前序未提交代码算进本批。batch1/migration.tsv、evidence.json、model-artifacts.json、callers.txt、baseline-reconstruction.json、workspace-before/after.json和status-before/after.txt共同供复核。两个.res、90份清单和开发索引留在工作区；没有重复上传大包。
- 90效果声明在本批首次与最终生成间逐项相同，CLPS字节与任务开始时相同；清单更新来自完整输入策略身份，不是新增全库运行工作。当前没有运行中的自有Godot，无待批准/不明结果的代码执行。
- 给父任务source_thread_id=01a13943-4c97-7250-995c-9fd48247000f发送一次进度的app接口返回MCP -32000工具错误，送达未确认，未重试。代码执行与本地证据不受影响，最终回复由平台通知父任务。

待父任务处理的是终极画面15像素严格比较差异及摄影翼尖取景限制；其余模型/材质/库存迁移继续保持未完成。此处停下，不自行扩批或再次拍图。

## 2026-10-19：有限修订1，保护前置停止

父任务批准只处理full重复资源、重复需求/准备中库替换、缓存dest_md5，以及一次终极0.3秒三图验证。本轮未扩其他模型、材质或池数量。

- 消费者审计只发现剑魔包装器及CPU探针依赖template.meshes.full，已明确迁移。配方删除full输出；包装器从源MeshInstance保存_full_mesh，只接受normal/wing两键模板，旧三键产物拒绝，无旧格式fallback。
- 所有权保存来源真实clip目录和实际选择闭包；固定模板始终准备全部声明clip，空请求表示该闭包；普通筛选路径空请求要求全部原来源clip。重复子集复用；扩展到缺失的真实clip返回本次失败记录，不污染仍有效的根记录。准备中核对库身份，完成及显式begin核对动画集合；每步不重复扫描全部已完成clip。模板来源库被更换也拒绝。ModelVisualResources同步晚发错误，避免PackedStringArray快照漏报。
- 开发生成验证source_md5及dest_md5；后者对dest_files顺序串联实际字节散列，包含所有声明纹理格式。check在缓存存在时执行同一检查；完整未导入的干净检出可只检查源/产物，write始终要求完整缓存，部分缺失拒绝。未加入运行hash。
- 窄CPU源新增：普通子集/扩张/空需求、字段键、固定完整闭包/漏clip/替换模板、准备中替换库和晚发错误传播、full不再出现在模板及导入mesh共享；探针先载入渲染脚本检查可实例化，再执行模型合同。本轮未实际执行该Godot合同。
- 定向渲染源改为仅剑魔Passive_Attack_Ult 0.3秒 generated→legacy→generated；用当前蒙皮顶点世界范围确定固定相机，保存根/Model变换、全骨骼局部/全局姿态、蒙皮摘要、mesh/material/skin及modifier身份、投影边界；保持严格图像相等和完整翼尖检查。没有普通/圆盘/整场渲染，当前唯一一次定向渲染额度未使用，脚本尚未经引擎编译验证。
- 沙盾仅model_visual_resources.gd pin因step_bind晚发错误传播更新，明确静态审阅成功路径未变；没有新增CPU/渲染通过证据，也没有修改sample/Shader/几何/绘制次数。原资格32项证据保留为原身份，不能称本轮重测。
- 本轮资源工具9项先通过；添加多格式dest_md5合同后，仅复验3项model定向检查，全部通过，涵盖缓存同尺寸/恢复mtime损坏、第二纹理格式损坏、空缓存与write严格需求。无引擎、无整场。
- python3 tools/dev.py resources --write由同一监督器执行，但budget在启动前报告Insufficient normal-pressure system headroom before launch，确认未启动Godot；随即停止全部引擎操作，不重试、不调整限制。新模板未生成，原.res SHA仍是上一批值；resources --check失败仅列6项源/策略过期，不能手改索引放行。
- 阻塞动作：生成新模板及其后CPU/唯一一次定向渲染；目标为当前两模型开发产物与终极三图；原因是既有≥8GiB/normal启动条件未满足。状态为保护拒绝启动，不是审批拒绝，不是执行结果不明；无自有Godot待清理。

恢复条件后应从相同resources --write开始，再CPU编译/合同通过后执行唯一一次--render。不要重跑已通过Python或其他场景。完整本轮增量diff和工作区身份在本机revision1证据目录；不再发送父线程通知API。

## 2026-10-19：一次恢复检查与授权重试，仍未启动引擎

父任务要求只检查一次实际条件，满足才重试一次。检查值pressure=1 normal、available=53%，估计9,105,330,667字节（8.48GiB），原门槛8,589,934,592字节（8GiB）；进程表只有用户编辑器PID/PGID6389，无本轮遗留进程。因此执行一次原resources --write，不关闭应用、不降门槛。

这次仍在Python离线CLPS生成/全量等价验证及元数据投影后、Godot启动前的budget(state)失败。目录resource-artifacts/20261019-004347-153364/仅有3,660,227字节projections.json，没有engine.log或guard结果，确认未启动Godot。现有guarded_engine在budget通过之后才写preflight，故失败瞬间的实际压力/余量数值未留存；不能用前置53%冒充该瞬间读数或断言必由Python占用造成。未进行第二次外部内存查询、第二次生成重试、CPU或定向渲染。

两份模型.res、索引、CLPS均与修订前字节一致，源/产物6项失配未解决；门禁不绕过。一次生成重试额度已使用，唯一一次定向渲染仍未使用。具体前置数值、进程行、目录证据与输出身份见revision1/recovery-preflight-second.json及recovery-second-result.json。下一步可先改为在budget之前持久化实际内存和本进程RSS供归因，再由父任务决定是否让离线加工子进程退出释放内存或按精确输入身份复用未变化CLPS；此处仅建议，未实施、未放宽保护。

## 2026-10-19：工具观测与阶段内存生命周期修正（仅窄Python/mock）

父任务禁止再次原样重试，批准本轮只修工具并做小验证。没有完整生成、Godot、游戏、渲染或系统设置修改，未commit/push；模型修订与旧.res/索引失配仍未解决。

代码证据：旧encode保留raw+解析文档并构造int64/float64数组和payload，verify再次读取/解析同源并持有解码载荷，project第三次解析该紧凑源；函数返回后未找到帧图的长存引用，旧generate明确保留的是元数据projections和小compact_report，allocator未归还驻留只是未证实的可能，不能当作既定根因。新路径读取/解析紧凑源一次，原文散列后释放raw，同一文档完成编码/完整位校验和元数据提取，随后释放数值图再逐项处理其他源。

- 新resource_offline_worker在独立短命进程中生成证据目录内的sampled.clps、projections.json，最后原子写report.json；父进程只读≤1MiB小报告、SHA和路径，不解析帧或投影。safe_probe确认退出/回收成功后才进行下一阶段。进程退出能清除该worker私有堆/allocator驻留；不能保证系统可用比例随即恢复，故Godot仍原门槛重查。
- 新resource_process复用原safe_probe：离线worker与Godot串行、各20秒/1GiB、启动6秒/主线程心跳2秒、ready+256MiB，自有组确认清理；启动normal/≥8GiB、运行normal/≥4GiB均未降低。无后台心跳线程，单次JSON解析/压缩也可能因实际阻塞触发保护。完整源尚未测，不能保证新worker必能在限额内成功。
- 所有保护拒绝之前先存preflight的真实pressure/available/physical、父RSS、PID和UTC/单调时间；读取失败保留null与错误，停止。运行中先写触发系统状态和实际组RSS，再让监督器中止；watchdog/guard/rejection共同保留时间、原因和清理。所有日志/产物写失败不忽略。
- 输出是逐文件同目录临时写、flush/fsync、replace；完成报告最后写。worker/报告/源身份/产物SHA/清理失败均不进入Godot，不改正式CLPS或索引。Godot成功且输入稳定才原子复制CLPS，最后原子写索引；原生.res仍沿用既有写入，未另造跨文件事务。若中途出现部分正式产物，旧索引和check继续拒绝，修正原因后重跑统一入口，不手改SHA。
- 窄验证累计73项：进程/流水线14（先12通过，再分别验证新增engine-failure与源结构拒绝合同）、compact6、projection2、resource_artifacts10、verify41。覆盖真实微型worker独立PID/退出/reap，源只解析一次，精确int64/float64与符号零，拒绝前数值保存，pressure/RSS/超时/既有非editor/版本/清理失败，worker完成后才进入mock引擎，输入/报告/文件被改拒绝，以及原子替换失败保留旧字节。fixture日志中的Generated/FAIL来自临时小工程和预期失败，不是完整生成或Godot。
- 收尾补强低余量拒绝的同次组RSS记录，对受影响的pressure与RSS/超时两项合同定向复验通过。verify --plan已审阅；它包含前序全部未提交修改而扩大到引擎/广泛套件，本轮没有执行这些步骤。一次单测命令从根目录导入失败（maintenance模块路径），改为该工具目录的正确入口后两项通过。
- 用保存的修正前codec实际执行一个微型1行夹具，新旧编码451字节及校验报告完全相同，SHA=beebc0e15d5baba15f8f297dd00420d037a1ee6d7bb759f83363cf8c5d70cfe7。该证据不替代全库/全源位验证。

当前新证据足以建议一次新方案验证：先观察受保护离线阶段的peak RSS、拒绝前真实数值、退出/清理及父RSS，再看Godot前同门槛重查；若任何阶段失败停止，不调限额。此处不执行，等待父任务决定。原唯一一次终极定向渲染仍未使用。完整增量diff、初始/最终工作区SHA、对象生命周期表和fixture证据在本机model-ownership/tool-memory/。

## 2026-10-19：新方案一次完整生成，离线RSS保护停止

父任务批准一次新方案完整生成，成功才继续窄CPU与唯一一次终极0.3秒generated→legacy→generated全翼对照。本轮无代码修正、无再次尝试。初次只读观测被沙箱阻止执行/bin/ps，未启动任何工作负载；同一观测取得系统读取权限后成功，不是自动审批拒绝。

- 初始17:08:58.848 UTC：pressure=1、available=58%，9,964,324,126字节（9.28GiB），满足原8GiB；只有用户编辑器PID/PGID6389，无自有残留。统一入口随后仅执行一次。阶段前17:09:19.175 UTC仍58%，父RSS30,441,472字节。
- 实际目录resource-artifacts/20261019-010919-174956/offline/。worker PID/PGID82795；原20秒/1GiB、6秒启动/2秒主线程心跳、ready+256MiB、normal/运行≥4GiB均保留。2.3848835秒时以rss_limit停止，采样峰1,201,553,408字节（1,145.89MiB），超过1GiB上限127,811,584字节。它是实际采样峰，不能当作未被终止时的完整峰值。
- 最后系统观测17:09:21.394 UTC仍pressure=1、available=57%，9,792,525,434字节（9.12GiB）；组RSS采样时间17:09:21.539 UTC。运行父RSS最多30,736,384字节（29.31MiB），未持有源数值图。此次失败是worker自身RSS限额，不是系统余量、墙钟或心跳失败。监督器最后读取的阶段为compact:encode-frame/sequence8；文件末次心跳已到compact:verify-frame/sequence9，不能进一步把峰值归给某一条具体分配。
- 清理TERM，leader exit=-15，confirmed=true、remaining_live_pids=[]。离线未产生sampled.clps、projections.json或完成report.json；Godot阶段目录不存在，未启动Godot，不执行CPU/渲染，也没有图像可比较。唯一一次终极定向渲染仍未使用。前序15像素差异没有新的通过证据。
- 本次独立resources --check返回1：聚合错误列出10项过期输入，源/产物尚未恢复一致。两份模型.res、CLPS、索引四项全部SHA/字节数与本轮开始一致。未手改清单或资格、未改阈值、未commit/push，HEAD仍f4a0fb79a4b47374653aa28a751899f5dba4c1cb。

实测支持进程分界限制父进程驻留，但完整worker仍未满足1GiB约束，不能宣称新流水线成功或实际性能改善。后续应先静态审查数值图与typed数组、payload/解压及Python ID元组的重叠峰值，再以小夹具改造编码/校验生命周期；本轮没有执行这些改造或再次测量。证据为model-ownership/new-pipeline-trial/的initial-preflight、generation-result、outputs-before/after、check-console及evidence.json，底层保护原始值保留在上述offline目录的preflight/health/last-rss/watchdog/guard/rejection中。历史73项窄测试不计入本次通过数。

## 2026-10-19：只读增量与峰值分析，方案尚未接入

本轮只改本记录，分析原型与小夹具放忽略的model-ownership/incremental-analysis/；生产生成器/资源/索引没有变化。未读取86.76MB虚空源、未解压完整CLPS、未运行大源/引擎、未重试或改限额。仅读取94658字节CLPS头、既有索引、代码和旧日志；10份约3.66MB投影只流式核对SHA，其内容相同但没有受信任的逐产物来源记录。

为什么模型修改仍重烘焙虚空：resource_artifacts.generate无条件调用prepare_offline，后者worker无条件compact encode+完整verify，然后才进入Godot模型生成；没有逐项dirty判定。inputs/policy_digest还把全脚本、模型、效果和工具绑定一个身份，并将全局policy_sha写进全部效果头。全局变动本不等于所有产物重建，现有实现确有不必要耦合。

此次不能直接复用旧CLPS：旧索引compact_samples.py SHA为c560bc4f7180b783081783fc12891e74be74ca8fa6e65b1e6ccdd4dfef0c4a4d，保存的旧文件核对相同；当前为ed674f409d165f0419f7082ed20134a7a18089737fd5a1065f58054dd127c1bb。函数抽取、raw生命周期和progress路径确实变更，尽管格式字符串与微型输出相同，也不能给完整源作未变声明。旧索引只有全局inputs、binary SHA及检查计数，缺少逐产物producer/validation绑定。CLPS头的source SHA与旧索引一致，但本轮不读取大源，不冒充当前源内容重新验证。正式首次迁移应完整重建/再验证，不批量签新成功记录；未来逐产物记录齐备后，单改模型不应再重建CLPS。

有界AST复核补充：将旧URI/SHA/stat表达式明确映射到新参数、仅去掉progress观察调用后，encode数值主体与verify主体相同；decode整函数AST相同。因此本轮**没有证明数值算法/格式改变**，默认重建/再验证是producer文件身份和新完成契约不能直接继承的保守选择，不能伪称数学上必需。若父任务选择直接迁移legacy CLPS，须另行明确审阅旧/新producer绑定、当前源SHA、旧位校验证据/产物SHA及版本证据，不将AST归一化变成自动签发器。本轮未实施该例外。

待实施的最小分批方案（复用既有唯一resources框架）：

1. 增加build_records：每个CLPS/逐源投影/逐recipe模型记录真实源与上游产物SHA、输出形成代码SHA、格式/策略/运行库或导入版本、完整校验契约；build_key绑定完成校验及产物SHA/bytes。复用时实际按块hash输入和输出；mtime不参与。缺记录/失配重建，缺输入报错，全局摘要只作索引快照。纯保护/编排只有在输出逻辑明确归回现有codec/projection后才能排除producer，不能追溯伪装本次旧身份不变。
2. worker只接dirty jobs；投影按源独立缓存，虚空投影可从受信CLPS有界header.data取得，其他源只解析变化项；无dirty离线项不启动worker。单模型配方/源/所有形态clip/导入/builder身份变化只加工该模型，未脏recipe在load/instantiate之前跳过。
3. 首个MVP可每次轻量resolve全部90variant以发现新增/删除/动态声明，只读已验证的小投影，不解析帧数据。完整动态调用闭包未建立前不承诺逐variant计算缓存。比较实际resources/raw/selection，仅发布变化清单；来源头改成各自producer closure，全局policy改变不能强制重烘焙全部资源。未知输入先轻量归属，仍无法映射则拒绝，不静默“已覆盖”。
4. 合并复用与新结果，复核逐项真实输入、产物、资格、expected集合/孤儿/导出依赖，再最后原子发布同一总索引；check同时验证总快照与逐项记录。实际依赖输出和运行端只读边界不改。现有非跨文件事务的失败拒绝边界保留。

峰值代码证据：compact_samples.py:58的三段tobytes拼接，在原typed数组P之外还会同时有字节临时P与最终payloadP；数值图D仍在。确定P=134420536字节(128.19MiB)。CPython3.14微型对象尺寸代入441667×38行的代表估算D约544.20MiB，D+3P约928.78MiB，尚不含嵌套容量、解释器、压缩工作区及allocator；没有读取实际类型分布，不能称精确占用或严格下界。verify又保留D并解压P、struct.unpack_from建立整组ID/offset整数元组；values是view，不是另造1634万个float。实测只定位编码/校验交界，未精确定位触发分配。

优先修正方案是不造流式JSON框架：预扫frame/layer计数，单bytearray(P)+缓存Struct.pack_into写整行，ID仍int且逐值finite/int64检查保留，避免两份P（当前尺寸约256.39MiB）重叠；encode buffer不外泄，verify ID/offset使用有界读/view，保留独立完整位比较。当前标准库Zstd接受bytearray已用tiny-buffer确认。该降低量是代码推算，不是已测全源收益，不承诺1GiB内必成功。

预算区分：没有证据证明模型任务或游戏本质必须>1GiB；可信缓存齐备时模型-only只需SHA/元数据及Godot，不该为无谓重烘焙扩限。当前完整对象实现的dirty compact重建+完整位校验确实已超过1GiB，仍应先优化buffer。若评估后保留原完整对象实现做单次诊断，可供明确批准的**离线worker临时候选1.5GiB**，相对采样峰有390.11MiB/34%余量，非已证明足够或最低必要值；Godot仍1GiB，启动normal/≥8GiB、运行余量建议更紧≥6GiB，原20秒/6秒启动/2秒心跳和自有组清理不放宽，失败立停无自动重试。本轮没有申请或实施这个预算。

incremental_plan.py独立判定原型的12项小夹具通过，实际做1行CLPS编码/位校验和投影，模型仅假产物。覆盖模型/无关全局变化不失效，真实source/producer/format/policy改变失效，同尺寸恢复mtime仍查出损坏，缺/坏记录及验证后输入变化拒绝。生产入口未导入原型，不把它写成已实施增量生成。完整可执行方案proposal.md、原型/测试、compact旧新代码diff、analysis.json和evidence.json同目录；当前生成一致性与唯一渲染仍阻塞，未追加本轮引擎通过数。


## 2026-10-19：增量接入与一次生成成功，CPU编译门禁停止

本轮按授权接入最小增量，不增加通用任务系统或软件依赖。原HEAD/main及前序修改保留，所有新增代码与已有14文件的阶段基线在model-ownership/incremental-implementation/；未修改其他英雄包装器、效果执行器、资格pin或库存。

- resource_build_records为CLPS、每源projection、每recipe模型与每份清单保存真实source/producer/格式策略/完成契约和产物SHA/bytes。全局inputs仍作完整门禁快照，单项key决定加工。no-op认证记录/内容后不启动子进程；model-only不解析数值源，未脏recipe在load/instantiate之前跳过。效果请求仍在全局输入变化时轻量resolve全部90variant，不宣称已做动态调用闭包缓存。
- worker只执行offline-plan显式jobs；认证的CLPS有界header提供虚空投影，其余dirty源逐项解析/finite验证，暂存后才写完成报告。父进程只合并约3.66MB小元数据，不接收数值帧图。Godot只建engine-jobs指定模型；复用/迁移/新建同入一个总索引，索引最后原子发布。损坏/缺记录不被旧SHA或mtime直接认可，部分发布失败保留旧索引，下次重新认证，实际依赖输出不变。
- 单buffer严格保持SoA：offsets→全部IDs→全部float64，ID和float分别按位置pack_into；不能照早期方案文字将整行交错写入。先计数，单分配payload，原int64/finite检查和独立decode/全行bit验证保留。旧参考编码主体保存在窄测试内，对照4/5/38列、1/3层、4帧、空层、int64边界/float ID、符号零/极小极大数和Unicode，整包bytes完全相同。没有新完整虚空源编码或单buffer全源峰值测量。
- 显式迁移记录tools/source_assets/compact_reviews/void_summoning_v2.json绑定旧源SHA、CLPS SHA、旧索引、原始完整位报告、旧工具c560…、前buffer工具ed674…及当前工具/函数SHA。旧参考主体与前buffer主体、当前decode及verify主体身份核对相同；新增buffer不是字面同一编码函数，其布局证明与微型字节合同单列。迁移origin=reviewed-legacy-v1、new_full_source_validation=false；只认证原已验证文件，没有把迁移写成新全源重算。原Python/Zstd补丁版本未独立留档等限制写入审阅记录；write不自动续认。旧投影即使10份SHA相同也未直接复用。

本轮窄Python合同38项通过：compact8、process7、artifact10、新增量12及verify路由1。首次新增量合同有1项因损坏CLPS在no-op头检查过早抛错失败，已修复并仅复验失败项及受影响no-op/model-only/部分失败三项；没有重跑完整工具/游戏套件。fixture日志Generated/FAIL均来自微型临时项目/mock引擎，真实微型worker退出/reap合同独立执行，不混入本次完整生成结论。

真实一次生成：resource-artifacts/20261019-014613-357269/，开始2026-10-18 17:46 UTC。预检及阶段启动均normal、64%/10.24GiB，只有用户编辑器6389，无自有残留；原20秒/1GiB、6秒启动/2秒心跳、ready+256MiB、启动≥8GiB/运行≥4GiB全部保留。离线2.908733秒/峰201621504字节(192.28MiB)；随后Godot3.757334秒/峰373506048字节(356.20MiB)，两个owned group均正常退出且清理confirmed、无剩余PID；parent峰约49.55MiB。此为本次开发加工进程数据，不是游戏加载收益，也不是single-buffer全源收益。

| 本次种类 | 实际范围 | 证据/限制 |
| --- | --- | --- |
| CLPS | migrate 1，build 0 | 当前源按块SHA匹配旧源、完整CLPS内容SHA认证；未重新解析/编码/位比较86.76MB虚空源 |
| 投影 | build 74 | 虚空1项来自认证header，其余73源各自解析验证；从旧散落投影直接复用0项；最终全部metadata与旧aggregate深比较一致 |
| 模型 | build 2 | 剑魔normal/wing新模板、圆盘；首次缺逐项记录均构建；未扩其他模型 |
| 效果清单 | build 90 | 首次记录及各自policy key；77定义/43provider/90variant；resources/raw/selection逐份相同，dependency_changes=[] |

入口内部check和随后独立resources --check均0错误。剑魔.res=1571044字节，SHA=fb8e3acd35aad574df5b6185ed818f479d65307d2b1ef8d0bffd1b7535e68b9d（移除模板full，仍用导入原full）；圆盘.res=35236字节，SHA=247f7dae701cc332af4e225a8fd289ab635001df68997dbf93a031f22a0576b1；CLPS=10522360字节，SHA=12e5a5f8c45a258a5a89e0d5a047a4e364adf941711949d2052a0dcedd34bbea，未变。总索引512266字节，SHA=41eb3f0edf6601a81717bb6c4c07b0b79128e380d6c0766e26f5d5ebeb046a1e。

之后只执行一次窄CPU：model-ownership/20261019-014719-158297/。共48项/47通过，aatrox每实例20次clip复制/step、sun_disc6次；唯一失败dedicated render script compiles before single render。实际引擎日志指出tools/maintenance/model_template_render.gd:162的shared变量无法推断类型，整体passed=false/exit1。0.624801秒、峰246235136字节(234.83MiB)，normal/10.24GiB、自有组清理confirmed，无RSS/心跳/墙钟超限。这是预先放置的编译门禁捕获，不是渲染结果。按父任务“失败停止”未修改该脚本、未再跑CPU、未执行唯一一次终极generated→legacy→generated；无新图像，不能宣称旧15像素已解决或视觉通过。

恢复资源一致性已经完成；当前阻塞操作是通过该摄影脚本编译并执行仍未使用的终极对照，原因是上述明确源码编译错误，不是权限拒绝/未知执行结果。后续须父任务决定修复与定向复验，不自动重试。关键core.incremental.diff、逐产物action/SHA、两个阶段guard、独立check、CPU结果与workspace身份在本机incremental-implementation证据目录，未重复打包上传。


## 2026-10-19：只复验编译门禁，唯一终极三图严格通过

父任务明确授权修复局部测试编译错误并复验受影响范围，不重复已通过47项。仅将model_template_render.gd的shared改为显式bool；model_contracts.py新增互斥--compile-render，model_ownership_contract.gd在同一加载/可实例化检查后，compile-only模式直接保存一项结果并退出，不执行check_requirements/check_failures/check_model。因此47项模型合同函数及生产所有权代码未改，沿原代码身份复用。原失败目录20261019-014719-158297完整保留，不覆盖为成功。

verify --plan对三个探针工具路径返回未映射/需显式scope（exit2），原始计划留档；本轮明确选用既有受保护model_contracts --compile-render及--render，不因未映射隐式跳过或运行完整游戏套件/import，也没有为此扩工具框架。compile-only目录20261019-015251-389716：1项通过，无模型实例；0.517523秒，RSS峰206831616字节(197.25MiB)，normal/≥10.24GiB、自有组清理confirmed。未再跑38项Python或47项模型合同，未重生成资源。

唯一一次终极对照目录20261019-015318-778306：Passive_Attack_Ult、0.3秒，generated-first→legacy→generated-repeat，720×1280、gl_compatibility；6项全部通过、failures=[]。三张PNG SHA均0d57b2433ffc029028ac058505a4477123902915be0325411d3ba6c4f5691d20，独立逐像素核对三对均0差异、bbox=null。未调整阈值，未增加第二次渲染。目视检查generated及legacy完整原图，翼尖/武器/足部在框内，非只凭图像摘要判定取景。

- 三图projected bounds均(72.000015,351.217407)–(648,926.887085)，fully_framed=true；固定正交camera.size=9.065567，camera origin=(0.742500,4.621262,7.874570)，完整camera矩阵保留result/render-evidence。
- pose_equal=true：root/model局部及全局矩阵、Skeleton全局矩阵、全部127根骨骼局部/全局矩阵相同；clip/time/player_root/speed一致。三次5392蒙皮顶点SHA均648cd5dec65ef084aca30c1975287d10071bc430b7d7db547e22816e46d9a95d。
- full mesh确为同一只读导入ArrayMesh：ID=-9223372008518056472、RID=446676598784、path=ultimate.glb::ArrayMesh_l42yo；Skin身份也共享。generated root/player/Skeleton分别32799458777/32883344981/32849790428，legacy分别33336329781/35282486833/35248932399；活体身份不同，原材质身份/override/overlay与modifier细节全部保存。重复generated使用同一活体身份，证明三图的次序稳定性。
- 渲染1.005871秒，RSS峰279199744字节(266.27MiB)；启动及运行normal，最低系统可用10823317585字节(10.08GiB)，原20秒/1GiB、6秒启动/2秒主线程心跳、ready+256MiB与8/4GiB门槛保留。正常退出，owned group清理confirmed、无残留；无整场/其他模型/额外姿态。

这里证明的是新模板+原full mesh共享、该0.3秒姿态在完整取景条件的严格相同，不把旧15像素的不同取景结果强称同条件根因已测。单buffer大源性能、整场收益、其他英雄、不可达材质和库存继续未测/未迁移。本次只改探针与同一记录，生产生成输入及167项产物身份保持生成成功时的状态；不因探针修复重新烘焙大源或刷新索引。

最终复核要点：resource_build_records.spec/reusable以逐产物来源/producer/format/validation/output内容认证；resource_artifacts.offline_plan/prepare_offline/generate只执行dirty jobs、轻量重解声明、合并复用/迁移并最后发布唯一索引；compact_samples.encode_document为单SoA buffer，独立位验证保留；compact_legacy_review.migrate绑定真实旧源/文件/旧索引与完整位证据、新旧工具/函数及新buffer小合同，origin明确不是新全源通过；ModelAnimationInstance.begin/step以根记录移交一次实例库/Animation并拒绝不兼容需求或替换；剑魔normal/wing开发模板、原full导入共享及圆盘Attack遮罩前移。旧包装器先复制、通用bind再复制的链已删除；仍未迁移项以上表为准。

render-closure/保存这次四文件基线、编译/渲染console和guard、render-evidence（含完整矩阵/像素/identity）、增量diff及最终复核身份；incremental-implementation/core.incremental.diff与generation-evidence、product-identities仍保留为上一节点的真实快照，不覆盖失败历史。没有父线程通知接口调用、没有提交推送。


## 2026-10-19：后续批次2，整表面过滤与通用材质可达准备

### 范围、实现与代码身份

本批从HEAD `f4a0fb79a4b47374653aa28a751899f5dba4c1cb`、main和全部前序未提交工作继续，没有reset、暂存、commit或push。开始快照位于素材库`04-中间产物/构建与验证/model-ownership/batch2/`，包含workspace-before/status-before及已脏核心文件的原文。旧CLPS、90效果清单、原源GLB/纹理/导入设置均未改；数据与资源准备不能影响权威20Hz或玩法。第四阶段容量/初始数量/慢实例安全判定未改，新增模板脚本仍按原有脚本判定保守满建。

核心改动：

- `ModelVisualResources.bind_model/begin_bind(root, allowed, material_states={})`增加可选提前准备集合；原始overlay/override/surface/shadow引用仍完整保存。绑定先建普通/受击槽，冰冻槽初始别名base；隐身只保存原引用而不建ghost。可达/首次实际请求才创建与旧值一致的普通冰冻、建筑冰霜或ghost，stasis优先时不创建普通冻层。无buff时后三槽仍别名前三槽；buff/建筑类型改变时重建正确链；reset/clear恢复原始引用。金身仍按需准备，没有扩状态禁用逻辑。
- `MatchModelPool.material_states_for(uses, plan)`在路径实例创建前按同路径全部形态/阵营取stealth_delay并集、按本局target_states取freeze，并传入初建、refill、miss与UnitModel3D样本。计划本身不重写，沿用已验证的形态/成长/升级/召唤/死亡替换/复活/镜像闭包。freeze可作用于双方和衍生物，不能用“当前未冻”裁掉；控制与快照实际状态请求仍可懒准备。不改变库存或动作/状态传播。
- `model_template_builder.gd`整表面操作改为`source.duplicate(false)`后倒序`surface_remove`，不重建surface数组，保留原生格式、顶点通道、LOD、blendshape/模式/名称、材质、custom AABB和shadow_mesh；mesh节点支持精确相对路径。`material_textures`只对指定静态表面克隆材质并替换纹理。没有引入英雄名单。
- `model_template_view.gd`是小型共用包装：安装可选只读body网格并声明既有v1动画契约；直接摄影同步准备，池设置defer后统一bind。Sion只覆写几何初始化和原实例部件切换；两种鱼保留原部署时钟、显隐、粒子、骨骼挂点和reset。所有活体Animation/播放器/Skeleton仍独立，模板不能写入动态状态。

### 每模型/材质迁移与保留

| 模型/范围 | 本批决定 | 运行仍保留/后续约束 |
| --- | --- | --- |
| 奥恩 | 原6表面保留0/1/2，删Sword/Bucket/Poro；14clip模板，1,344,117字节 | 预览focus不变；没有可变材质写入 |
| 卑尔维斯 | 原2表面保留Body，去HEAD并静态换ultimate_body；12clip，714,359字节 | 女皇散出鱼的权威/部署逻辑未改；材质模板共享只读 |
| 赛恩 | 原2表面保留body生成unarmed；12clip，657,681字节；full只引用导入网格 | berserk/Death/Passive_Death第23帧选择和reset每实例；无当前动作时source_time=0，避免旧空动作读时错误；无脚本的被动独立场景未改 |
| 近战虚空鱼 | 确认原源只有最终1表面，旧过滤实际无效但仍重复克隆；现直接复用导入mesh，模板meshes为空，4clip/41,519字节 | 源网格不重复序列化；女皇零部署出生与正常部署遮罩状态独立 |
| 远程虚空鱼 | 原2表面保留1，去Melee；5clip，84,017字节 | 同名skinned_mesh父节点与网格并存，配方用精确路径；BackSpine_end投射挂点/部署状态未变 |
| 剑魔/太阳圆盘 | 通用生成器保全属性后重建；剑魔normal/wing仍2份派生，20clip/1,633,034字节；圆盘6clip/35,236字节且产物SHA不变 | full仍引用导入原网格；48项CPU复验；本批未重拍两者，原首批严格终极0像素结果仅属于当时身份 |
| 隐身/冻结/金身 | 不可达ghost/freeze不创建；原材质快照和六槽消费者接口保留，实际请求懒准备 | 材质仍活体私有；含buff时不擅自省略采样；金身维持原按需策略 |
| VoidGate | 本批保留原加工，未宣称必要或已完成 | 需同时输出Spit只读delta与绝对clip、延长Death；运行Idle相位与骨骼叠加不能烘掉，当前整表面操作不解决加法时间线 |
| Yorick | 本批保留披风拆面/IdleIn裁剪 | 需单独输出body/cape并保持Skin/transform/骨骼路径/exclude_hit_flash；随机UV、两层shader、age及两modifier仍私有；有可迁移部分，非永久保留结论 |
| Gnar | 本批保留三角裁切/加法合成 | 整表面删除不能替代按权重裁三角；需覆盖4/8影响、LOD/blendshape索引、时间并集/scale override与多导出参数 |
| Kayle | 本批保留源加工 | 几何/静态换纹理仍可前移；rage strength/elapsed、材质next_pass与强化shader参数必须先拆出私有层 |
| Pantheon | 本批保留源加工 | living/death过滤仍可迁移；rage每表面next_pass/elapsed、头盔modifier与死亡第77帧、落点粒子状态须独立审查 |

未迁移项是下一批的明确缺口，不以“有脚本”证明永远必要。本批不重写特效采样、不调整库存，不启动全牌库或整场A/B/C。

### 实际生成范围与资格

- 成功生成`resource-artifacts/20261019-020611-709506/`：77定义/43provider/90variant；build=7模型（含受通用producer变化影响的剑魔/圆盘），reuse=165（CLPS、74投影、90效果清单）。无dirty离线项，offline worker未启动，不读87MB虚空数值源，不重算/迁移CLPS。
- 随后移除近战鱼无效mesh输出，`20261019-020812-751282/`仅build voidfish.res，其他171份认证复用；源脚本小修触发轻量全请求解析，未重烘焙无关模型。最终独立check 0错误。全部动作与输入/产物身份见actions/engine-jobs及最终索引。
- 沙盾pin的pool/binder/UnitModel3D改变，已静态逐项审阅：几何、Shader、sample和callback未改，基础/强化六槽别名契约仍保持；新增的是可达材质参数转发/懒准备。先执行材质16项和沙盾CPU32项通过，再明确续记这三项pin和证据/限制；write未自动认可，beam资格不变。未重拍沙盾宿主。

### 定向验证、失败与限制

先审阅本次verify --plan，自动17套件/导入范围过宽，改用既有受保护窄入口，没有照跑该宽计划或全量verify。

- `model-ownership/20261019-020419-749233/`材质16项通过：无能力材料不建、原快照、受击/冻结优先、普通/建筑层、buff链、排除闪白、重复重用、回收、stasis不误建普通冻；镜像/变形/召唤/转换/死亡替换/复活闭包及freeze传播。随后完整本批合同在`20261019-020841-338958/`103项通过，还覆盖每模型保留surface数量/format/primitive/name/顶点数组/blendshape数组/LOD数据/AABB/shadow属性、静态纹理、全部保留clip的length/loop/step/type/path/interpolation/keys/transitions等值、Skin/节点骨骼路径/transform、两实例共享只读模板及独立动画、赛恩形态/第23帧/reset、鱼部署reset。未建库存或启动Unit权威战斗。
- 首批直接消费者`20261019-021118-331787/`48项通过（47所有权及原renderer编译），因本批改了共享binder/mesh producer才复验；没有重拍剑魔/圆盘。
- 沙盾CPU`effect-coverage/20261019-020427-611940/`32项通过；不是新宿主渲染或全第二阶段覆盖。
- 新renderer编译1项`20261019-020918-701849/`通过后，唯一一次真实渲染`20261019-020928-255900/`12项通过：奥恩base/freeze/stealth与卑尔维斯base四组generated/独立重述legacy比较均0像素差，8图逐一蒙皮顶点投影完整取景；720×1280/Godot4.7.1/Compatibility、同动作0.3秒。已逐张目视四张生成图，形态、部件、纹理、冻结和隐身表现无异常。该有限代表不等于赛恩/鱼逐卡渲染、全动作、工作台实际战斗或整场性能通过。
- Python增量工具12项、资源工具10项通过；资源工具中打印FAIL来自预期坏PCK夹具，unittest最终OK。源/产物check为0错误。最终文档/项目审计及diff结果在本节收尾补记。
- 历史失败完整保留：普通沙箱无法读系统观测而在引擎前停止；批准相同保护执行后，首次小夹具完成但探针没发ready（结果16通过，guard拒绝），补ready仅复验夹具通过。两次模板生成分别因远程鱼不存在Meshes、同名父节点遮蔽真实网格而明确失败；受保护树检查确认后以精确路径修复。失败期间部分.res已写，索引/check照常拒绝，后续成功才恢复。首次完整CPU102项中，材质对象身份断言不适合跨原生序列化、近战鱼误以为应删表面及赛恩空动作读时明确失败；改为全存储材质值/纹理检查、删除真实无效加工、修正读时后仅复验本批，103通过。不改像素/等价阈值糊弄失败。
- 所有引擎均原20秒/1GiB、6秒启动/2秒主线程心跳、ready+256MiB、30FPS，启动normal/≥8GiB与运行normal/≥4GiB；无并行引擎、扩限、用户程序/OS修改。成功7模型生成4.098秒/415,383,552字节峰值，最终单模型生成3.647秒/318,078,976字节，本批CPU1.108秒/271,204,352字节，代表render1.584秒/287,817,728字节；均自有进程组cleanup confirmed/无剩余live PID。这些是工具验证进程数值，不是实际加载收益。

本批停在可审阅状态：没有待批、自动审批拒绝或执行结果不明事项；未测整场加载提速，不能把单模型或本轮验证RSS相加当收益。第三阶段上表缺口、第二阶段其余热点与第四阶段库存由父任务继续推进；最终统一环境清理/分批commit/push尚未执行。

批次2收尾：纯文档verify计划0领域套件、无导入/无引擎，实际audit与diff-check通过；独立resources --check仍0错误。完整核心增量diff、当前文件SHA、迁移表、生成/验证证据索引及status-before/after统一在本机batch2目录，未覆盖其他工作。只清理了本批自建/tmp编辑脚本，保留模型源件、生成产物与必要失败/成功证据；最终全项目清理与提交交父任务统一执行。


## 2026-10-19：严格材质修订，修复前述未满足的首用合同

### 实际改动

- 模式明确：ModelVisualResources.bind/begin要求mode=match/tool；正式attach在卡牌/阵营/路径门禁后设置完整view.material_states。未规划状态、buff、路径和模式不符明确失败，owner错误经UnitModel3D/BattlePresentation3D信号进入Main原资源失败入口；直接工具、预览、演示和测试显式tool，不提供正式静默懒fallback。
- 闭包：沿用MatchResourcePlan的召唤/转换/升级/换形/死亡替换/复活/本方镜像选择闭包；同path双方/各形态合并stealth及freeze/stasis目标状态。buff从过滤后的visual_active_buff_scene、visual_radius/radius、实际阵营生成描述集合（含观察者阵营映射）。初建/refill/计划内miss/样本使用同一集合。非战斗额外场景不误造目标状态候选。
- 私有候选：每库存owner加载时准备ghost、普通/建筑frost、gold、各可达buff节点及make_overlay链和hit/frost变体。基础与buff候选缓存；configure_buff/select/reset只选择，不再清空重建基础hit/frost。统计按kind去重计数候选资源，107项合同检查合法切换和挂接/回收前后计数/身份不变。
- 生命周期：buff节点固定挂在模型根，top_level变换在最终位姿后同步，样本移动也同步。附属几何和骨骼附件标记排除模型覆层/包围盒；不是把缓存效果当身体。reset_prepared_visual及少量已有效果覆写复位fade、age、origin、临时粒子状态；preserve显式支持、无模型overlay时交换已准备节点保留时钟，不支持的转移拒绝。模型根take/recycle也会触发_exit_tree，因此VoidSpawn/Tristana缓存挂点不在树移交时销毁，真正owner.clear调用release_prepared_visual清理；真实take/recycle/take与真正释放已验证。
- 生成器：抽出小process_mesh，纯纹理替换不再被空exclude吞掉；实际无删除/替换返回无输出，不复制整网格；非空shadow_mesh未知映射明确拒绝。原生容器复制保留完整表面数据，源不修改。
- 工具：通用wrapper准备返回PackedStringArray结构化错误，包括子类几何初始化失败；池、代理、模型/相机/封面展台处理失败，WorkbenchModelPreview复用根动画所有权，删除旧二次深复制。同步已触及测试的显式模式，以及LoadingAssetsSuite残留的旧runtime-wrapper模板引用；没有执行完整该suite。

### 验证和证据

素材库证据根仍为`04-中间产物/构建与验证/`，本修订基线与完整diff在`model-ownership/material-revision/`。HEAD保持f4a0fb79a4b47374653aa28a751899f5dba4c1cb、main，前序修改保留，无暂存/commit/push。

- 最终严格合同`model-ownership/20261019-025714-808291/`107项通过：mode/未声明状态拒绝且零创建；同path双方不同能力并集；32种hit/freeze/buff/stasis/stealth组合零候选创建；私有材质隔离；挂接/reset/reselect保持基础/buff引用；真实生产attach的召唤成员、Gnar换形及镜像来源卡重复挂接；控制/快照标志触发覆层；两个夹具库存无miss回收。计划成员来自真实CardDB，模型/普通buff用极小夹具，没有执行完整镜像施法或权威战斗。
- 同一合同还实际执行pool.prepare、sample、refill状态机和已知库存miss，核对相同严格计划与预建gold/ghost/frost；miss明确计数为1且会分配，不纳入“零新增”结论。真实五层Tryndamere工厂、Jinx私有时钟保持、VoidSpawn骨骼挂点经真实take/recycle/take不误删、真正release释放挂点、Darius fade/age复位，以及生成器纹理/no-op/shadow和工具失败/直接消费者编译均通过。
- 生成后五模型直接合同`20261019-025033-685607/`103项通过；首批所有权`20261019-025246-382868/`48项通过。后续两处仅收紧非战斗候选/失败返回及真正释放，成功几何/clip路径未改；相应新增边界包含在最终107项，不重复全套。
- 沙盾CPU`effect-coverage/20261019-024738-249757/`32项通过。ActiveBuff/base pool/binder/UnitModel的pin经逐项审阅、107及32项证据明确续记；后续释放hook对沙盾继承no-op，几何/Shader/声明/sample/callback不变，未重跑沙盾或新拍宿主对局。write不自动认可资格。
- 唯一完整代表渲染`model-ownership/20261019-025019-541076/`中base/freeze/stealth/buff四组均0像素差，但stasis失败138536像素；如实保留整体failed。诊断确认生产attached_mesh shader使用TIME，两次顺序截图不处于同一着色器时刻。没有修改生产shader、隐藏差异或放宽阈值；探针改同帧两个隔离视口，编译`20261019-025214-796334/`1项通过，仅复验stasis `20261019-025223-449317/`4项通过、0像素差、零新候选且完整取景。四个已通过状态未重拍。已目视buff及同帧gold两图。不是冷GPU/完整宿主或全效果首帧证明。
- 首次增量生成`resource-artifacts/20261019-024937-076293/`build10（7模型+3份来源脚本身份改变的清单）、reuse162；随后窄修订`20261019-025513-343353/`build0/reuse172。CLPS与74投影全部复用，未启动离线worker、不重读87MB虚空数值JSON；新清单的资源/选择声明未改，只是源身份改变。最终释放hook修订另有一次生成和独立check，结果在本节收尾写明。
- 失败完整保留：夹具忘设Unit.card_id；相机初始投影位置错误；池仅接受assets路径而夹具在tests路径（改用内存别名，未改白名单/创建正式假素材）；探针局部类型/缩进错误；误将沙盾ActiveBuff.bind_model适配成资源owner接口（已撤销该误改）；金身跨帧TIME差异。局部修正后仅复验相应小范围。曾有一次编辑基线脚本拒绝新测试文件后仍启动旧夹具，旧相机失败再次保留；没有把重复失败算通过。
- 所有引擎保持20秒/1GiB、6秒启动/2秒主线程心跳、ready+256MiB、30FPS、normal且启动≥8GiB/运行≥4GiB、仅自有进程组清理。107及生成/渲染的guard与cleanup保留；无并行引擎、扩限、关闭用户程序或改OS，无审批拒绝或结果不明动作。

### 未完成边界

零候选创建只指已准备owner管理的覆层/ghost/frost/gold及buff make_overlay返回链，不覆盖动态粒子/拖尾/按帧网格/效果内部材质；Tryndamere、Jinx、小炮等已有动态入口仍属于第二阶段剩余热点。所有计划内库存miss仍可能同步实例化/准备，容量/初始库存/安全阈值未改，第四阶段必须另评；未测完整对局启动时间/RSS或冷GPU首帧。截至这次严格材质修订，VoidGate/Yorick/Gnar/Kayle/Pantheon仍未迁移；随后本批状态见末节。本次只修本批材质和已识别生成器/工具错误边界，最终统一清理/分批提交由父任务继续。

本修订最终生成`resource-artifacts/20261019-025746-461198/`build7/reuse165，独立check0错误；七份.res与修订开始全部字节SHA相同，因此几何/clip数据等价结果按相同产物身份复用。生成4.103秒/417,546,240字节峰值；最终107项1.115秒/337,821,696字节峰值，均cleanup confirmed/无剩余live PID。纯文档审计首次把测试内存PackedScene别名误识别为磁盘资源，保留2项失败日志；改为等值的显式动态别名表达式并说明用途，没有创建假素材或放宽审计。该测试字符串表示变更不重启引擎；最终audit/diff结果与工作区SHA在material-revision证据目录。


## 2026-10-19：剩余确定性加工有限批次

本批基线HEAD仍为`f4a0fb79a4b47374653aa28a751899f5dba4c1cb`、main；所有前序未提交工作保留。实施前逐路径SHA、文本快照、当前身份及完整增量diff在本地`model-ownership/remaining-models/`。只完成下表的四类迁移；不是整个第三阶段或五阶段优化完成，停下供父任务复核，无暂存、commit/push。

| 模型 | 正式结果 | 每实例保留与限制 |
| --- | --- | --- |
| VoidGate | 模板4clip，19,291字节；Spit从Idle1与delta合成为绝对动作、Death长2.2秒；无网格或原delta副本 | 直接引用导入原Spit delta；连续Idle相位/骨骼叠加及粒子状态/尾迹不前移 |
| Yorick | 模板8clip，886,971字节；body/cape原生拆面、IdleIn长1秒且不循环 | 双层shader、每次复位随机UV、披风路径和武器混合modifier/历史独立；动作入口不重复begin所有权 |
| Kayle近/远程 | 同一模板15clip、normal/ranged两网格，1,821,211字节；远程body静态纹理前移；配方及指纹显式包含独立kayle_ranged定义 | wings shader/next_pass、怒气强度和时钟每实例surface override；无运行网格重建 |
| Gnar小/大 | 小模板8clip/599,228字节，大模板10clip/765,717字节；原道具表面/骨骼三角过滤和加法合成前移，仅存filtered网格 | 原full直接引用；动作选择、播放器/骨骼和叠加历史独立。精确保留原四权重阈值公式、scale/pose时间并集、起点重映射和第二主体动作 |
| Pantheon | **保留本批开始时原包装器与场景，SHA完全一致**；候选及其.res只存本地素材库，配方和孤儿正式产物已移除 | 候选数据与材质隔离通过，但死亡2.7秒仍有14个严格像素差。未默认认定运行筛面永久必要；候选方案曾前移living/death过滤，留下两个承载私有next_pass的浅网格容器，后续须先解决渲染差异再接入 |

### 核心实现与消费者边界

复用现有builder/索引/ModelAnimationInstance所有权，不增并行引擎或中央英雄名单。builder增加clip_settings、absolute_delta、composed_animations与表面include/索引exclude；纯算术移到开发工具model_animation_ops，并纳入两处生产器输入。新增五份配方、五份.res和六个包装场景引用。原始full网格不重复序列化。source原生surface复制保留压缩顶点、skin、blendshape、名称、材质、AABB及LOD。骨骼过滤仅替换主索引和各LOD索引字节，按16/32位原生布局编码；四影响布局、三角形/非空索引、已解析bind是明确边界，未知shadow、其他布局或空surface/LOD策略拒绝。实际大纳尔保留全部LOD阈值及按原公式过滤的索引。

静态审计追过UnitModel、池/样本、摄影与模型工作台、原卡牌小套件的直接调用；删除的Gnar加工参数只出现在旧包装/旧场景及本地对照，不存在运行消费者。实际CardDB的kayle_ranged是deployment_upgrade_id引用、不是transformed_stats；补齐此配方闭包后才完成消费验收。通用材质严格实现、本局能力闭包、候选计数边界、库存及覆盖资格pins未改；前批107/32及原七模板证据按未变身份复用，未随write自动续记资格。

### 数据、渲染与失败证据

- 先看本批verify --plan，自动8套件含权威/重型入口过宽；实际选择本文小合同、生成门禁和文档审计，无full/全牌库加载/整场A/B/C。
- 初版232项数据对照`20261019-031348-394415/`通过；补充完整私有next_pass链、原生blendshape/custom AABB/LOD夹具等后，270项`20261019-031619-654634/`通过。对照使用实施前完整脚本快照生成独立旧实例，动画length/loop/track/path/插值/key/time/value/transition逐项相同；source全通道和原生字段、LOD、材质值、skin/transform/shadow、两实例时钟/材质/modifier/动画隔离、反复prepare及reset均覆盖。内建材质序列化后对象身份不保证相同，按完整属性/纹理引用核对。
- 最终只复验受影响Yorick、Kayle两形态及Pantheon精确恢复身份：`20261019-032328-908196/`145项通过。此前未变VoidGate/Gnar数据与夹具复用270项的相同代码/产物身份。
- 六个真实模型/形态经正式UnitModel3D采用预建资源：`20261019-032259-427204/`26项通过。实际MatchResourcePlan含部署升级闭包，按真实配置收集clip；同一owner移交及freeze/stasis/hit候选复用成立。没有建全局库存、运行权威变身命令或整场战斗，不能等同于完整集成或首用零分配。
- 首次四代表同帧渲染`20261019-031632-439859/`整体**failed**：VoidGate连续Idle1.7秒+Spit.35秒、Yorick IdleIn.3秒、Gnar大形态Rage_Spell2_Transform.55秒均0像素差；每对完整取景、骨骼蒙皮顶点近似等价。Pantheon Death2.7秒差14/921600像素，bbox=(488,672)-(522,736)，RGB最大差156/131/68。未把该差异或整体失败写作通过。
- Pantheon定向数据诊断`20261019-031726-628491/`71项通过；主数组通道全部相同，原生差别为LOD和表面名称。仅给旧参照补回源LOD的`20261019-031816-071522/`仍差14，恢复私有材质创建顺序后`20261019-031954-749586/`仍差14。两项假设未解释差异，**根因未定位**，不宣称LOD导致。候选CPU再次71项`20261019-031939-394124/`通过，但正式实现随后恢复基线。原始图、候选、探针及所有失败完整保留；不放宽像素阈值、不继续盲拍。后续更小的诊断可先核对死亡姿态逐骨骼矩阵/浮点位及实际draw排序，再决定迁移；不需扩大整场压力。
- 其余失败包含：Pantheon局部类型推断（已修，候选后撤）；JSON数字Array.has与整数类型不同导致小纳尔漏筛面（改显式int比较）；探针误要求序列化材质同对象；量化权重边界与非法同长度LOD夹具；compile分支未发ready；消费者相机位于投影退化平面。均有原日志，修正后只复验相关小范围；无保护阈值放宽、审批拒绝或不确定动作。编译门禁最终`20261019-031805-977219/`1项通过。

### 实际生成范围、身份与剩余工作

首次`resource-artifacts/20261019-031004-268064/`build103/reuse75：13模型（含后撤Pantheon候选）与因生产器工具身份变更的90清单；CLPS和74数值投影均复用。此后13模型的纯加工修正每次仅build13/reuse165；最后一次为`20261019-031447-995063/`。移除Pantheon配方后`20261019-032101-439027/`build0/reuse177，清除孤儿正式.res；Kayle闭包修正最后`20261019-032218-551225/`仅build1/reuse176。没有启动offline worker、解析87MB虚空源JSON或重算CLPS。原七份模型.res至本批结束与起点SHA全部相同；正式最终12模型/90清单/74投影/1CLPS合计177个有记录产物。

所有引擎沿用20秒/1GiB、6秒启动/2秒主线程心跳、ready+256MiB、30FPS，整机normal且启动≥8GiB/运行≥4GiB，仅清理自有进程组。没有关闭用户程序或修改OS。完整guard、耗时/峰值和cleanup汇总在remaining-models/evidence.json；本批清理只处理自有临时编辑脚本与已退出受保护进程，不清用户编辑器/源件/前序证据。

Pantheon仍待等价诊断；第二阶段其余采样/动态效果热点、第四阶段初始库存、全局收尾仍由父任务继续。新增五模板约4.09MB磁盘，原GLB仍为依赖、其完整导入动画可能驻留；每活体动画及私有状态仍有必要创建。本批没有整场加载/RSS/首帧测量，不作提速或内存下降结论；严格材质前批也仍待最终复核，不把候选零创建扩大为全游戏零分配。


本批收尾：22项Python资源工具测试通过（增量12、产物门禁10，后者stdout的FAIL是预期负例，unittest退出0），独立resources --check为0错误，文档audit为77卡/7161文件/0错误，diff-check通过。90份清单本批均仅policy_sha256随开发工具身份更新，resources/selection内容不变；已记录逐文件字段差异，不把其字节SHA说成未变。核心增量diff约113KB，28个代码/场景/配方/文档路径；另5份新模型模板、90清单及全局索引共124个本批变化路径。首轮270项CPU峰302,776,320字节/1.466秒，首次四代表渲染峰395,542,528字节/1.830秒（因Pantheon像素失败，非通过），最终26项消费者峰291,487,744字节/.994秒，145项受影响复验峰274,006,016字节/1.118秒，最后1模板生成峰380,059,648字节/3.745秒。七份旧模板SHA均未变；所有本批监督进程cleanup confirmed，最终自有进程组和临时文件清理记录同存evidence.json。


最终参照独立性复核：model_remaining_oracle从实施前场景读取Gnar全部加工参数及Kayle ranged标志，不从当前recipe反填旧实现；避免同源参数掩盖错误。仅大小纳尔`20261019-032823-778710/`48项复验通过，原CPU产物/运行代码未变，不重拍。三张通过的VoidGate/Yorick/Gnar代表生成图已实际目视，完整取景、未见部件或姿态缺失；Pantheon失败图亦已查看。24个本批自有进程组最终只读检查均无活PID，没有向用户程序发送信号。新工具/配方文本身份、参照快照和严格失败结果均保留供复核。
