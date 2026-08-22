# AGENTS.md — AI 协作约定

本文件供 AI 助手（TRAE / Claude 等）在本项目中工作时遵循。

## 项目概况

- **Clash Legends**：类皇室战争的 1v1 卡牌即时对战游戏，LoL 角色题材（个人学习项目，不发布）
- **引擎**：Godot 4.x 标准版（非 .NET），脚本语言 GDScript
- **总规划**：见 `docs/DEV_PLAN.md`，修改代码前先确认当前处于哪个阶段

## 如何运行

1. 用 Godot 4.x 打开本目录（识别 `project.godot`）
2. 按 F5 运行主场景 `scenes/main.tscn`
3. 核心机制回归：`Godot --headless --path . --script tests/mechanics_check.gd`
4. 美术接入还必须在编辑器或实际渲染中目视检查，不能只依赖 headless 测试

## 目录结构

```
project.godot        Godot 项目配置（竖屏 720x1280）
scenes/              场景文件（.tscn）
scripts/             GDScript 脚本
  data/card_db.gd    卡牌数值定义（改数值只动这里）
docs/                规划与文档
assets/              美术/音效资源（约定见 assets/README.md；大体积源文件不入库）
```

## 代码约定

- 使用 Godot 4 语法（`func _process(delta: float) -> void:` 全类型标注）
- 注释与 UI 文案使用中文，标识符使用英文
- 阶段 4 已允许接入美术资源；资源结构遵循 `assets/README.md`，3D 近战角色遵循 `docs/MELEE_3D_INTEGRATION.md`
- 美术表现不得驱动伤害、碰撞、寻路或联网权威状态
- 场景尽量由代码构建，保持 .tscn 文件极简，便于 AI 读写
- 战斗单位与塔都加入 `combatants` 组，统一接口：`team` / `hp` / `body_radius` / `take_damage(amount)`

## 硬性原则（对应 DEV_PLAN 第四节）

1. **先玩法后美术**：阶段 1-3 不接入任何图片/模型素材
2. **战斗逻辑纯数据化**：伤害、血量、位置计算不得依赖渲染帧率或随机外观表现，为联网同步铺路
3. **不过度设计**：只实现当前阶段需要的功能，不提前抽象
4. **每阶段可玩**：提交代码前确保 F5 能正常运行

## 当前阶段状态

- [x] 阶段 1 完成：核心原型（金币/卡牌/单位/塔/胜负）
- [x] 阶段 2 完成：占位 AI（AIOpponent）、8 张卡牌、3 分钟计时+加时+破塔数胜负
- [ ] **阶段 3 进行中**：ENet 主机权威联机（端口 39152）。主机端跑完整模拟，客户端只发部署 RPC + 收快照插值（`is_net_client()` 判断），新单位/新机制必须走 `_spawn_unit` / `_cast_spell` 才能被同步
- 无界面联机测试：`-- --mode=host --auto-test` / `-- --mode=join --ip=127.0.0.1 --auto-test`（headless 需配大 --quit-after）
- 新增卡牌先看 `docs/CARD_DESIGN.md`，数值只改 `scripts/data/card_db.gd`
- **阶段 4 进行中**：已加入竞技场背景与盖伦原始模型；按 `assets/README.md` 归档，表现层不得驱动战斗逻辑
- 接入剑圣、亚索等普通近战 3D 角色前，必须完整阅读并执行 `docs/MELEE_3D_INTEGRATION.md`
