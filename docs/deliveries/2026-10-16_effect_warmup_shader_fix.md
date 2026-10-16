# 改动记录：特效预热访问不存在的粒子字段

## 当前结果

修复 `spell_effect_warmup.gd` 对所有播放器直接读取 `_data` / `_pools` 的假设。玛尔扎哈 R 光束、区域为程序化 Shader 效果，不持有这两个粒子字段；现在由其资源声明提供预热采样时间，粒子播放器仍逐层补齐出生帧。修改预热兼容逻辑、对应效果声明、契约文档和回归，不改战斗规则。本轮统一提交与同步记录见[工作区整理](2026-10-16_window_warmup_workspace_sync.md)。

## 2026-10-16：修复与验证

- 原因：实际运行日志定位到 `_sample()` 的 `sample_ages(player._data)`。玛尔扎哈 R 的 `nether_grasp/player.gd` 没有 `_data`，结束统计处也不能读取不存在的 `_pools`。
- 改动：有粒子数据时继续使用原采样算法；无粒子数据时使用提供者声明的 `times`；仅对有粒子池的播放器统计粒子层数。
- 回归：将玛尔扎哈全部效果加入 `SpellWarmupSuite`，验证光束与区域的 Shader 材质实际保留、正常及取消后节点清理、重复预热与权威状态无副作用。
- 验证：headless 专项 `SpellWarmupSuite` + `MalzaharSuite` 共 684 项断言、0 失败；完整 `tools/dev.py verify` 通过 79 套件、15,227 项断言，`workspace_changed_during_run=false`，审计、导入、数值检查和差异检查均通过。
- 实际渲染：使用 Godot 4.7.1、OpenGL Compatibility / Apple M5 运行 `SpellWarmupSuite`，583 项断言全部通过，无脚本错误；用于确认真实绘制预热路径，不是技能外观的人工作品验收。
- 证据：`ClashLegends-开发素材库/04-中间产物/构建与验证/verification/20261016-150739-952869/` 下的 `result.json`、`mechanics.log`、`render-warmup.log`。全量日志仍有分段音频攻击序号、缺失水晶终局音频及退出时 6 个 ObjectDB 实例泄漏警告，未在本任务扩大修复。
- 状态：保留修复前已有的窗口适配等工作区修改；本任务未提交或推送。
