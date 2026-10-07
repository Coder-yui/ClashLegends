# Clash Legends

Godot 4.x / GDScript 的 1v1 卡牌即时对战学习项目。独立服务器/单机固定 20Hz，2D 权威模拟与独立模型、特效、音频表现分离。窗口 `720×1400`，战场 `720×1280`。

## 开始

当前验证版本为 Godot **4.7.1 标准版**（完整版本见 `godot-version.txt`），使用 GL Compatibility。目标为当前 Mac，手机暂不列入发布目标。Mac 导出见 [发布说明](tools/release/README.md)。

用 Godot 打开 `project.godot`，F5 运行 `scenes/main.tscn`。主菜单可进入单机、联机或 **卡牌开发工作台**。

```sh
Godot --path . -- --mode=workbench
Godot --headless --path . --script tests/mechanics_check.gd
```

工作台提供全卡搜索、模型旋转/缩放、动画暂停/定位、真实技能与控制测试、声音变体试听。完整用法见 [工作台手册](docs/DEVELOPMENT_WORKBENCH.md)。

## 开发入口

- [文档首页](docs/README.md)：按任务找当前手册；[任务导航](docs/AGENT_WORKFLOW.md)用于具体开发。
- [新卡与素材接入](docs/NEW_CARD_CHECKLIST.md)：五阶段执行、迁移记录与联合验收。
- [工具目录](tools/README.md)：音频加工、渲染演示和只读仓库审计。
- [模块与数据流](docs/MAINTENANCE_ARCHITECTURE.md)：Main 编排、battle 权威系统、逐卡定义、独立表现。
- [卡牌索引](docs/units/README.md)：当前卡牌与系统对象；定义位于 `scripts/data/cards/`。
- [测试与联机](tests/README.md)：统一 mechanics、server + 两个 join、真实渲染和试听要求。
- [当前待办](docs/DEV_PLAN.md)与[历史归档](docs/archive/README.md)。

普通卡复用通用 Unit；出牌统一经过 `play_card()`，新增机制扩展共享系统。素材和动画不能决定伤害、移动、碰撞或技能时刻。协作边界见 [AGENTS.md](AGENTS.md)。

素材与迭代：正式资源在 `assets/`；候选、制作中版本和产物统一在项目根目录的 `ClashLegends-开发素材库/`。宣传素材独立在项目根目录的 `ClashLegends-promo-materials/`。这两个目录是本地工作区，已由 `.gitignore` 忽略；需要进入游戏的最终资源必须同步到 `assets/`，来源和验收结论写入文档。分类与展台流程见 [任务导航](docs/AGENT_WORKFLOW.md)。

## 本地客户端—服务器对战

运行 `bash tools/run_local_multiplayer.sh`，自动启动无窗口服务器和两个客户端窗口。默认 UDP 端口39152，可用 `CLASH_PORT` 覆盖；关闭两个窗口或按Ctrl-C清理本组进程。该脚本直接使用默认卡组开局；需要自选卡组时，单独启动服务器，再打开两个普通游戏窗口，在菜单中选卡并连接127.0.0.1。

服务器命令：`Godot --headless --path . -- --mode=server`。两个客户端均使用 `Godot --path . -- --mode=join --ip=127.0.0.1`。服务器分配阵营，不占玩家席位；首期断线结束对局，不支持掉线重连。正常终局两端离开后服务器等待下一局。
