# 项目维护工具

`audit_project.py` 只读检查资源引用、Markdown 链接、卡牌注册与手册覆盖，以及目录边界。`test_audit_project.py` 提供错误检测夹具。

```sh
python3 tools/maintenance/audit_project.py
python3 -m unittest discover -s tools/maintenance -p 'test_*.py'
```

[单位手册](../../docs/units/README.md) 面向用户阅读，由编辑者维护中文数值、技能、动画与声音说明。修改实现时同时核对对应内容；审计通过不能代替数值与语义核对。此目录不再提供自动生成和覆盖用户文档的工具。
