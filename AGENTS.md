# AGENTS.md — AI 协作边界

Clash Legends 是 Godot 4.x 标准版（GDScript）的 1v1 卡牌即时对战学习项目。窗口为 `720×1400`；权威战场 `720×1280`，底部 120px 为 UI。

## 开始与验证

1. 先读 `docs/AGENT_WORKFLOW.md`，按任务类型选择最少当前专项资料；历史归档和交付仅在追溯或用户指定时定向读取，问题档案按具体任务读取。
2. 先看 `git status --short --branch`，不得覆盖用户已有修改。
3. F5 运行 `scenes/main.tscn`；内容审查进入“卡牌开发工作台”，用法见 `docs/DEVELOPMENT_WORKBENCH.md`。
4. 核心回归：`Godot --headless --path . --script tests/mechanics_check.gd`。
5. 美术任务还必须在实际渲染中目视验收。
6. 完整新卡按“2D 权威逻辑 → 3D 模型/动画 → 卡面 → 音频 → 联合验收”推进；音频按 `docs/AUDIO_INTEGRATION.md` 执行并在实际运行中试听。缺素材或未支持的事件必须记录，不得默认为已完成。

## 任务交付

每个任务完成后，按 [交付合同模板](docs/templates/delivery.md) 在 `docs/deliveries/` 填写简洁交付报告，最终回复给出链接。问题文档放 `docs/issues/`；没有文档时直接依据用户对话处理。工作台只作预览器，不承担验收记录或报告导出。具体流程见 [任务导航](docs/AGENT_WORKFLOW.md)。

## 必须保持的边界

- 主机/单机固定 20Hz 权威模拟；客户端只请求操作、接收 Snapshot 和表现事件。
- 动画、模型、卡面、特效和音频不能驱动伤害、移动、碰撞、寻路或联网状态。
- 普通单位 = `CardDB` 数据 + 通用 `Unit`，不建立每英雄一个 Unit 子类。
- 生成走 `_spawn_unit()`，法术走 `_cast_spell()`；玩家、AI、RPC、DevelopmentWorkbench 卡牌动作走 `play_card()`。
- Unit/Tower 通过 `BattleContext` 使用战场服务，不得重新引入 `current_scene` 反向探测 Main。
- 每卡定义位于 `scripts/data/cards/<card_id>.gd` 的 gameplay / visual / card_art / audio 域，CardDB 统一注册查询；共享定义递归只读，运行实例持有自己的状态。新增字段须有读取方、schema/validator 与回归。
- `radius` 是权威半径；`visual_radius` 与模型缩放只影响表现。
- 战斗对象加入 `combatants`，提供 `team`、`hp`、`body_radius`、`take_damage(...)`。
- `assets/` 仅放已接入资源及运行依赖，不存候选、失败版本或归档。素材与产物统一放项目根目录的 `ClashLegends-开发素材库/`，按待开发、候选讨论、制作中、中间产物分类；宣传素材独立放项目根目录的 `ClashLegends-promo-materials/`。这两个目录是本地工作区，已加入 `.gitignore`，不随代码提交；正式接入资源必须同步到 `assets/`。
- 找素材先归档到开发素材库内，复用 `tools/dev.py model` / `audio` 展示；仅正式接入后进入卡牌开发工作台。不得为每次讨论重写展台或将候选塞入正式配置。
- 实战试接入用 `tools/dev.py stage` 创建素材库内副本，完成验证后同步最终改动与依赖；当前制作中地图使用 `stage --arena --open`。输出路径、素材阶段迁移与备份边界见 [任务导航](docs/AGENT_WORKFLOW.md)。

## 代码入口

```text
scripts/main.gd                    比赛生命周期、初始化与编排
scripts/battle/                    固定时钟、比赛规则、命令排程、移动/结算、单位控制/攻击时间线、弹体/快照
scripts/ui/development_workbench.gd 卡牌开发工作台；独立模型预览在 ui/workbench/
scripts/ui/deck_builder.gd         备战卡组与卡牌详情 UI
scripts/data/card_db.gd            只读定义注册与查询；内容 cards/，字段 card_schema，校验 card_validator
scripts/unit.gd                    通用单位入口；ControlState / AttackTimeline 持有对应状态
scripts/presentation/              只读权威状态的 3D 表现代理
scripts/audio/                     只读表现事件的音频入口
tests/mechanics_check.gd           统一入口；领域套件在 tests/suites/
```

结构维护先读 `docs/MAINTENANCE_ARCHITECTURE.md`；禁止回迁 Main 私有数组别名，固定时钟不可静默丢 Tick。

阶段状态见 `docs/DEV_PLAN.md`；新增卡牌和素材的阅读路径见 `docs/AGENT_WORKFLOW.md`。
