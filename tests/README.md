# 测试目录

`mechanics_check.gd` 是唯一的自动回归入口，领域实现集中在 `suites/`，卡牌特有机制放在 `suites/cards/`。

```bash
Godot --headless --path . --script tests/mechanics_check.gd
```

需要实际渲染、人工观察的场景属于开发工具，统一放在 `tools/demos/`，不混入自动测试目录。
