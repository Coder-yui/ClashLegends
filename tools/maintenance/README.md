# 项目维护工具

`audit_project.py` 只读检查资源引用、Markdown 链接、卡牌注册与手册覆盖，以及目录边界。`test_audit_project.py` 提供错误检测夹具。

```sh
python3 tools/maintenance/audit_project.py
python3 -m unittest discover -s tools/maintenance -p 'test_*.py'
```

[单位手册](../../docs/units/README.md) 面向用户阅读，由编辑者维护中文数值、技能、动画与声音说明。修改实现时同时核对对应内容；审计通过不能代替数值与语义核对。此目录不再提供自动生成和覆盖用户文档的工具。

统一执行与证据归档使用 `python3 tools/dev.py verify`，实现见 `tools/verify.py`；`test_verify.py` 验证退出 0 仍有脚本错误、汇总缺失、套件遗漏、非零退出、超时与工作区身份等失败路径。联机和人工验收仍按 [测试手册](../../tests/README.md) 单独记录。
