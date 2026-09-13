# 文档与开发工作台整理验收

2026-09-11，macOS / Apple M5，Godot 4.7.1。保留上一轮尚未提交的结构收敛修改，在实际工作区继续开发；没有修改卡牌定义、原始素材或正式玩法数值。

## 交付

- 建立 docs/README 总索引，当前流程、专项参考、卡牌说明与历史记录分开；归档里程碑和上轮结构验收。
- 卡牌索引覆盖 24 个注册对象，补皮克斯和凤凰蛋说明，移除总索引重复费用表。
- DevelopmentWorkbench 替换旧 ArtDevPanel；全卡搜索、独立模型/动画观察、正式技能/控制/法术测试、音频变体试听、人工记录导出。
- 预览模型不产生权威状态；实战页之外暂停当前实验；强化法术开关只在开发会话生效。旧八卡槽实现和调用方已迁移。

## 验证结果

| 验证 | 结果 |
| --- | --- |
| 本轮基线 mechanics | 466 项通过；`/tmp/clash-workbench-baseline.log` |
| 最终 mechanics | 472 项通过，无 SCRIPT ERROR；`/tmp/clash-workbench-final.log` |
| 编辑器导入 | 无 SCRIPT ERROR；`/tmp/clash-workbench-import.log` |
| 全脚本加载 | scripts/tests/tools/assets/units 无加载失败；`/tmp/clash-workbench-audit.log` |
| 主菜单 / workbench CLI 启动 | 正常启动，无 SCRIPT ERROR；`/tmp/clash-workbench-menu.log`、`/tmp/clash-workbench-startup.log` |
| 实际渲染 | 模型、实战、音频、记录、无模型法术、强化法术和纳尔变形素材共 7 组截图；检查布局、长动画名称宽度和缺资源状态；`/tmp/clash-workbench-render.log` |
| 会话边界 | 渲染演示验证切离实战 Tick 不推进、返回恢复；退出清空当前实验 |
| 文档链接与格式 | Markdown 本地链接无缺失；git diff --check 通过 |

实际渲染可复跑 `Godot --path . --script tools/demos/workbench_preview.gd`，图片输出 `/tmp/clash-workbench-*.png`，没有把生成图片作为正式素材加入仓库。

回归新增覆盖无结果搜索保留选择、动画暂停定位不生成战斗对象、变形素材共享解析、试听切页清理、无模型/静音法术、人工结论按卡隔离，以及正式比赛拒绝开发强化开关。旧技能候选、资源调节与 Cast/Impact 回归保留。

## 未验证与范围限制

没有进行实际听感验收、全卡连续动画人工验收或手机实测；没有改动网络协议，本轮未重复 host/join。上一轮联机结果见同目录结构收敛记录，不作为本轮网络实测。

声音页检查配置变体，没有波形编辑或距离衰减；最终触发/混音应在实战页听。记录仅在本次会话保留，重要内容需导出；未提供跨会话自动恢复。独立模型预览显示素材片段，真实控制、转场、命中和技能必须回实战页检查。

当前操作手册见 [开发工作台](../../DEVELOPMENT_WORKBENCH.md)，本文仅保留本次验收证据。
