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

`export_card_facts.gd` 通过 Godot 读取编译后的 CardDB，导出机械数值；`check_card_facts.py` 将单位手册中的 `<!-- card-fact: 卡牌ID 字段路径 -->数值` 与导出值核对。首批三张卡及八个必需字段由检查器声明，删除标记、未知字段或数值漂移都会失败；普通中文玩法不改写。`verify` 自动执行导出和核对，JSON 留在本次验证目录。新增覆盖需在检查器登记卡牌并在其手册标记必需字段。

部署时间标记 `deploy_time` 仅指实体出现后的部署锁定；`pre_deploy_time` 为出现前预部署，通用命令缓冲不合入两者。`audit_project.py` 另检查突进、穿地形、致死换形对象不绕过 Unit 转换接口写字段；对应失败夹具防止审计静默失效。
