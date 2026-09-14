# Clash Legends

Godot 4.x / GDScript 的 1v1 卡牌即时对战学习项目。主机固定 20Hz，2D 权威模拟与独立模型、特效、音频表现分离。窗口 `720×1400`，战场 `720×1280`。

## 开始

当前验证版本为 Godot **4.7.1 标准版**（完整版本见 `godot-version.txt`），使用 GL Compatibility。目标为当前 Mac，手机暂不列入发布目标。Mac 导出见 [发布说明](tools/release/README.md)。

用 Godot 打开 `project.godot`，F5 运行 `scenes/main.tscn`。主菜单可进入单机、联机或 **卡牌开发工作台**。

```sh
Godot --path . -- --mode=workbench
Godot --headless --path . --script tests/mechanics_check.gd
```

工作台提供全卡搜索、模型旋转/缩放、动画暂停/定位、真实技能与控制测试、声音变体试听。完整用法见 [工作台手册](docs/DEVELOPMENT_WORKBENCH.md)。

## 开发入口

- [文档首页](docs/README.md)：按任务找当前手册；[任务 Router](docs/AGENT_WORKFLOW.md)用于具体开发。
- [新卡与素材接入](docs/NEW_CARD_CHECKLIST.md)：五阶段执行、迁移记录与联合验收。
- [工具目录](tools/README.md)：音频加工、渲染演示和只读仓库审计。
- [模块与数据流](docs/MAINTENANCE_ARCHITECTURE.md)：Main 编排、battle 权威系统、逐卡定义、独立表现。
- [卡牌索引](docs/units/README.md)：当前卡牌与系统对象；定义位于 `scripts/data/cards/`。
- [测试与联机](tests/README.md)：统一 mechanics、host/join、真实渲染和试听要求。
- [当前待办](docs/DEV_PLAN.md)与[历史归档](docs/archive/README.md)。

普通卡复用通用 Unit；出牌统一经过 `play_card()`，新增机制扩展共享系统。素材和动画不能决定伤害、移动、碰撞或技能时刻。协作边界见 [AGENTS.md](AGENTS.md)。

素材与迭代：正式资源在 `assets/`；候选、制作中版本和产物统一在项目根目录的 `ClashLegends-开发素材库/`。宣传素材独立在项目根目录的 `ClashLegends-promo-materials/`。分类与展台流程见 [任务导航](docs/AGENT_WORKFLOW.md)。
