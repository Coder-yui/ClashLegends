# AGENTS.md — AI 协作边界

Clash Legends 是 Godot 4.x 标准版（GDScript）的 1v1 卡牌即时对战学习项目。窗口为 `720×1400`；权威战场 `720×1280`，底部 120px 为 UI。

## 开始与验证

1. 先读 `docs/AGENT_WORKFLOW.md`，按任务类型继续读专项文档；不要默认通读全部美术教程。
2. 先看 `git status --short --branch`，不得覆盖用户已有修改。
3. F5 运行 `scenes/main.tscn`。
4. 核心回归：`Godot --headless --path . --script tests/mechanics_check.gd`。
5. 美术任务还必须在实际渲染中目视验收。

## 必须保持的边界

- 主机/单机固定 20Hz 权威模拟；客户端只请求操作、接收 Snapshot 和表现事件。
- 动画、模型、卡面和特效不能驱动伤害、移动、碰撞、寻路或联网状态。
- 普通单位 = `CardDB` 数据 + 通用 `Unit`，不建立每英雄一个 Unit 子类。
- 生成走 `_spawn_unit()`，法术走 `_cast_spell()`；玩家、AI、RPC、ArtDevPanel 卡牌动作走 `play_card()`。
- Unit/Tower 通过 `BattleContext` 使用战场服务，不得重新引入 `current_scene` 反向探测 Main。
- 数值与表现配置集中在 `scripts/data/card_db.gd`；新增字段必须有读取方并通过 `CardDB.validate_all()`。
- `radius` 是权威半径；`visual_radius` 与模型缩放只影响表现。
- 战斗对象加入 `combatants`，提供 `team`、`hp`、`body_radius`、`take_damage(...)`。

## 代码入口

```text
scripts/main.gd                    比赛生命周期、初始化与编排
scripts/battle/                    BattleContext、弹体、网络快照
scripts/ui/deck_builder.gd         备战卡组与卡牌详情 UI
scripts/data/card_db.gd            卡牌数据、查询 API 与校验
scripts/unit.gd                    通用单位权威机制
scripts/presentation/              只读权威状态的 3D 表现代理
tests/mechanics_check.gd           统一入口；领域套件在 tests/suites/
```

阶段状态见 `docs/DEV_PLAN.md`；新增卡牌和素材的阅读路径见 `docs/AGENT_WORKFLOW.md`。
