# 改动记录：赛恩护盾与真正死亡

## 当前结果

已将赛恩W接入通用护盾入口，统一真正死亡判定与收益资格。未改数值、表现资源或网络载荷。诺手夹具修正后，完整69套件/11590检查及本机三进程联网一致性重新通过，专项72检查也通过。未进行实际渲染目视或音频试听；本次仅机制修改。

## 2026-10-10：实现与回归

- 赛恩W沿用独立盾层及自然到期范围伤害，补齐准入、同批伤害后加盾和死亡移除。
- Unit先固定死亡/亡语起点/替身/狂暴结束/孵化结果；龙王资源、剑魔刷新、诺手处决重置和沙皇转化统一读真正死亡结果，保留表现died语义。
- 新增护盾正反顺序、一次性到期/清除/死亡/清场；赛恩与冰鸟各生命周期的资源及转化；重复致死、来源同批死亡、新生对象隔离和客户端重放回归。旧击杀夹具改为先真实致死。
- 首次沙箱导入因系统证书/编辑器设置权限失败；授权执行后四专项（SionSuite、ANIVIA_SUITE_SCRIPT、AzirSuite、shield_suite）通过。证据：本地素材库 `04-中间产物/构建与验证/verification/20261010-204355-796648/result.json`。

- 首轮完整回归运行69套件/11546检查，其中9项旧断言要求死亡建筑保留盾量而失败，其余通过；已改为存活期间衰血绕盾、死亡时清盾，补充诺手真正死亡处决刷新覆盖。该轮未进入三进程网络步骤。

- 上一轮完整验证：`python3 tools/dev.py verify --network`，Godot 4.7.1，69套件、11589检查、0失败；审计、工具故障夹具、导入、卡牌数值导出/核对、差异检查及三进程网络均PASS。服务器与两个客户端在Tick86终局一致，生命周期边界检查通过。证据：本地素材库 `04-中间产物/构建与验证/verification/20261010-204915-489268/result.json`。
- 收尾发现新增诺手测试中同实例重注册会清除来源技能ID，已恢复夹具身份并添加普通真正死亡的正向对照；仅测试变更，`verify --suite DariusSuite`通过。证据：`04-中间产物/构建与验证/verification/20261010-205223-766668/result.json`。
- 当前规则更新：`docs/status/CORE.md`、`BUFFS.md`、`IMPLEMENTATION.md`及赛恩/狂暴赛恩、冰鸟/蛋、沙皇、龙王单位页；修正赛恩盾持续3秒对应60Tick的原文笔误。
- 代码范围：`scripts/unit.gd`、`scripts/battle/active_skill_effect_system.gd`、`scripts/battle/combat_resolver.gd`。测试范围：Sion/Azir/Darius/AurelionSol、TimedFormCycle、NetworkLifecycle及三份建筑/数值自然寿命套件。未提交、推送或部署。
- 未验证与残余风险：未执行实际渲染目视、音频试听、跨机器联网和`--network-boundaries`故障注入；本次没有调整表现资源。完整机制日志退出时报5个ObjectDB实例泄漏警告，verify仍判PASS；任务前的 `20261009-163442-198050/mechanics.log` 已有同样5个警告，可确定此现象原有，但未确定是否为同一组对象，不开展无关泄漏修复。新增真正死亡分类为权威实例状态，不进入快照；客户端仅消费既有资源和实体生命周期结果。


### 最终工作区复核

- 诺手测试夹具修正后的完整 `verify --network` 再次PASS：69套件、11590检查、0失败，三进程终局一致。证据：`04-中间产物/构建与验证/verification/20261010-205417-507120/result.json`。
- 为使验收覆盖本记录的最终内容，固定最终复核输出目录为 `04-中间产物/构建与验证/verification/20261010-shield-true-death-final/`；运行 `python3 tools/dev.py verify --network --output ClashLegends-开发素材库/04-中间产物/构建与验证/verification/20261010-shield-true-death-final`。最终结果读取该目录 `result.json` 的 `passed`、`workspace_changed_during_run` 与前后内容摘要，运行后不再编辑项目文件。
