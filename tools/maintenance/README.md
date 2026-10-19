# 项目维护工具

`audit_project.py` 只读检查资源引用、Markdown 链接、卡牌注册与手册覆盖，以及目录边界。手册正文与[覆盖表](../../docs/reference/UNIT_DOC_COVERAGE.md)均须匹配全部注册定义及导航声明的形态例外。测试注册还检查脚本/方法存在、分组与目录一致、入口不重复及套件没有漏注册。`test_audit_project.py` 提供错误检测夹具。

摄影工具声明的输出路径（如`DEFAULT_OUT_16X9`）不要求文件预先存在；同一路径被`preload`、`load`或图片加载方法读取时仍须存在。此例外仅用于`tools/`输出，正式运行资源仍检查缺失与外部素材库污染。

```sh
python3 tools/maintenance/audit_project.py
python3 -m unittest discover -s tools/maintenance -p 'test_*.py'
```

[单位手册](../../docs/units/README.md) 面向用户阅读，由编辑者维护中文数值、技能、动画与声音说明。修改实现时同时核对对应内容；审计通过不能代替未覆盖数值与语义核对。此目录不再提供自动生成和覆盖用户文档的工具。

统一执行与证据归档使用 `python3 tools/dev.py verify`，实现见 `tools/verify.py`；`test_verify.py` 验证退出 0 仍有脚本错误、汇总缺失、套件遗漏、非零退出、超时与工作区身份等失败路径。联机和人工验收仍按 [测试手册](../../tests/README.md) 单独记录。

导航/形态例外由 `docs/navigation.json` 声明，修改路线时同步导航正文。当前事实使用 `<!-- current-fact: 源码相对路径 常量名 -->数值`，只检查显式声明的事实，不以中文关键词推断规则。历史原文的版本不参与事实比较，但链接和章节锚点仍检查，新增断链不能静默忽略。

`export_card_facts.gd` 通过 Godot 读取编译后的 CardDB，导出机械数值；`check_card_facts.py` 将单位手册中的 `<!-- card-fact: 卡牌ID 字段路径 -->数值` 与导出值核对。首批三张卡及八个必需字段由检查器声明，删除标记、未知字段或数值漂移都会失败；普通中文玩法不改写。`verify` 仅在相关定义/实体数值或显式全量计划需要时执行导出和核对，JSON 留在本次验证目录；纯文档只做静态事实核对，不启动引擎。新增覆盖需在检查器登记卡牌并在其手册标记必需字段。

部署时间标记 `deploy_time` 仅指实体出现后的部署锁定；`pre_deploy_time` 为出现前预部署，通用命令缓冲不合入两者。`audit_project.py` 另检查突进、穿地形、致死换形对象不绕过 Unit 转换接口写字段；对应失败夹具防止审计静默失效。


## 原生采样运行格式

统一入口为 `python3 tools/dev.py resources --write/--check`，版本化清单、源件/策略失效、编辑器/verify/导出门禁与新卡操作见[资源生成流程](../../docs/RESOURCE_ARTIFACTS.md)。`effect_dependencies.py` 只提供数值采样元数据投影，CLI 转交统一入口；不再生成旧依赖头。`compact_samples.py --check` 可独立重做虚空召唤全部 int64/float64 位等价和确定性生成检查。`resource_contracts.py` 顺序执行受保护微型格式与无源件隔离 PCK 合同，不启动对局或美术预览。

模型模板已并入同一resources --write/--check：配方在tools/source_assets/model_recipes，builder只加工离树导入模型，不跑包装脚本/对局。model_contracts.py默认运行剑魔/圆盘所有权小合同，--batch2运行整表面/材质闭包合同，--materials-only仅该批夹具，--compile-render只编译探针；--render为对应批次的独立最小摄影对照；均复用既有保护阈值。操作与输入失效规则见[资源生成流程](../../docs/RESOURCE_ARTIFACTS.md#模型模板与一次实例所有权)。

resource_offline_worker.py仅由统一resources入口的resource_process监督启动，不裸跑、不写正式assets。它仅执行offline-plan中的dirty CLPS/逐源投影jobs，生成暂存产物与最后的完成报告；退出/回收确认后才启动Godot。resource_build_records保存逐产物真实身份；model-only复用已认证特效产物，no-op不启动子进程；两阶段保留原保护门槛。resource_process在拒绝前保存真实内存/RSS/时间，所有写入失败显式停止；单文件原子发布、部分生成恢复和微型测试边界见[资源生成流程](../../docs/RESOURCE_ARTIFACTS.md#生成保护的观测与进程边界)。

严格材质补充入口：`python3 tools/maintenance/model_contracts.py --strict-materials`只跑小夹具、两个库存实例及直接attach/pool入口；`--strict-materials --render`为有限代表摄影，金身以同帧隔离视口消除TIME跨帧差异，`--stasis-only`仅复验金身。都复用原监督器，不是整场首用/性能证明。

剩余模型小批入口为`model_contracts.py --remaining --baseline <实施前源码快照目录>`：顺序加载单类模型，对照原动画、原生网格/LOD、私有材质和复位；`--select`缩到受影响模型，`--consumers-only`验证六个真实模型/形态的UnitModel资源移交。`--remaining --render`只运行VoidGate/Yorick/Gnar三种机制代表；Pantheon未通过严格渲染、正式实现保持原样。快照和候选只存在本地素材库，不进入运行assets或导出；没有快照时数据对照明确停止，不用当前实现充当旧参照。

模型库存收敛入口为`python3 tools/maintenance/model_inventory_revision.py`：默认纯账单/全定义选择和巨大批量/深度/循环门禁；`--mode capabilities`只逐一检查六个模板，`--mode scheduler`只查虚拟时钟调度及真实取消信号清理，`--mode compile-runtime`只编译，`--mode runtime`显式启动一次真实Runtime小轨迹。使用同一resource_process保护，不自动串跑/重试或扩大整场；首轮/旧储备/构造能力、单步补货和真实有限轨迹结果见[库存契约](../../docs/MODEL_POOL_DEMAND.md)。旧手写事件库存探针已移出运行工具目录，源与证据只保留素材库。`--mode failures`仅用小夹具验证补货四阶段错误只通知Main一次、取消释放，以及死亡替身工厂null保留原错误；不运行对局、sampled家族或渲染。
