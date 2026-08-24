# Clash Legends

Clash Legends 是一个使用 LoL 角色题材、模仿皇室战争 1v1 对战的 Godot 学习项目。项目只用于个人本地学习，不发布、不上架。

当前主线是阶段 3 的 ENet 主机权威联机和阶段 4 的美术接入：主机运行完整的 2D 固定 20Hz 战斗模拟，客户端接收快照并插值显示；3D 模型、卡面和特效只属于表现层，不能驱动伤害、碰撞、寻路或联网状态。

## 快速开始

### 环境

- Godot 4.x 标准版（非 .NET）
- Git
- macOS、Linux 或 Windows 均可；下面的命令把 `Godot` 替换为本机可执行文件路径即可

在 Godot 中导入项目根目录的 `project.godot`，然后按 F5 运行 `scenes/main.tscn`。默认窗口是竖屏 720×1280，游戏内先选择卡组，再点击我方半场部署卡牌。

### 命令行检查

在项目根目录执行：

```bash
# 核心机制回归
Godot --headless --path . --script tests/mechanics_check.gd

# 本地运行
Godot --path .

# 无界面联机冒烟：先启动主机，再启动加入方
Godot --headless --path . -- --mode=host --auto-test --quit-after=20
Godot --headless --path . -- --mode=join --ip=127.0.0.1 --auto-test --quit-after=20
```

`--quit-after` 是联机回归时建议使用的外部退出参数；如果本机 Godot 版本不识别它，可在终端中手动结束进程。Godot 编辑器或实际渲染中的美术验收不能由 headless 检查替代。

## 给 Agent 的开发入口

每次继续开发前，先读以下文档并判断当前改动属于哪一类：

1. [`docs/AGENT_WORKFLOW.md`](docs/AGENT_WORKFLOW.md)：从接到需求到验证、提交的完整工作流。
2. [`docs/CARD_DESIGN.md`](docs/CARD_DESIGN.md)：卡牌字段、数值曲线、普通卡与特殊机制的边界。
3. [`docs/ART_PIPELINE.md`](docs/ART_PIPELINE.md)：通用美术目录、表现合约和接入顺序。
4. [`assets/README.md`](assets/README.md)：资源目录、命名和卡面约定。
5. 近战 3D 角色读 [`docs/MELEE_3D_INTEGRATION.md`](docs/MELEE_3D_INTEGRATION.md)；远程角色再读 [`docs/RANGED_3D_INTEGRATION.md`](docs/RANGED_3D_INTEGRATION.md)；所有手牌部署动画都读 [`docs/UNIT_DEPLOYMENT.md`](docs/UNIT_DEPLOYMENT.md)。

最重要的项目约定：

- 卡牌数值只改 [`scripts/data/card_db.gd`](scripts/data/card_db.gd)；不要在 UI、模型或测试里复制一份数值。
- 新单位、新建筑和新召唤物统一经过 `main.gd` 的 `_spawn_unit()`；新法术统一经过 `_cast_spell()`。
- 主机/单机走权威模拟，客户端只发送部署 RPC、接收快照和播放表现。
- 普通单位优先通过 `CardDB` 数据字段接入，不为每个角色复制 `Unit` 或 3D 状态机。
- `radius` 是权威碰撞体积，`visual_radius` 只影响画面；不要为了模型大小修改战斗半径。
- 动画回调不能扣血、移动单位、改变碰撞或触发联网状态。
- 改完代码必须跑 headless 机制检查；接入或调整美术还必须 F5 目视检查。

## 常用改动位置

| 需求 | 首先查看/修改 |
| --- | --- |
| 卡牌费用、生命、伤害、类型、体型 | [`scripts/data/card_db.gd`](scripts/data/card_db.gd) |
| 新法术效果 | [`scripts/main.gd`](scripts/main.gd) 的 `_cast_spell()` |
| 新的单位行为、状态或攻击规则 | [`scripts/unit.gd`](scripts/unit.gd) 与 `main.gd` 的权威入口 |
| 卡牌卡面 | `assets/cards/<card_id>_loading.jpg/png/webp` |
| 3D 单位 | `assets/units/<card_id>/source/` 与 `<card_id>_view.tscn` |
| 塔/水晶表现 | `assets/towers/`、`scripts/presentation/tower_model_3d.gd` |
| 机制回归 | [`tests/mechanics_check.gd`](tests/mechanics_check.gd) |
| 战场、塔位、联机常量 | [`scripts/main.gd`](scripts/main.gd) 顶部常量 |

## 项目结构

```text
project.godot                 Godot 项目配置和窗口设置
scenes/main.tscn               极简主场景；战场大部分由代码构建
scripts/data/card_db.gd        卡牌数值和表现配置的唯一来源
scripts/main.gd                主场景、权威模拟、部署、法术、联机快照
scripts/unit.gd                单位权威状态、寻敌、移动、攻击和死亡
scripts/tower.gd               防御塔/水晶权威状态
scripts/presentation/           3D 表现代理，不参与战斗逻辑
assets/                         原始模型、包装场景、卡面、背景等
docs/                           规划、卡牌和美术接入流程
tests/mechanics_check.gd        无界面核心机制回归
```

## 提交前检查

```text
[ ] card_id 使用稳定的英文 snake_case，且 CardDB 条目字段完整
[ ] 普通卡没有误改通用系统；特殊机制已接入主机权威入口
[ ] 新资源放在正确目录，未手工修改 .import 文件
[ ] Godot 可打开项目，F5 能进入可玩对局
[ ] tests/mechanics_check.gd 通过
[ ] 美术接入已检查部署、待机、移动、攻击、死亡、阵营方向和脚底位置
[ ] 联机改动已检查 host / join 的生成、快照、命中和死亡表现
[ ] git diff 只包含本次需求，提交信息能说明改动
```

更细的操作顺序和排错方式见 [`docs/AGENT_WORKFLOW.md`](docs/AGENT_WORKFLOW.md)。

## 当前范围与后续方向

已经具备现有卡池、占位 AI、计时与破塔胜负、ENet 主机权威同步、快照插值、兵线、范围伤害、击退、冲锋、冰冻、墓碑和多类 3D 角色/建筑表现。后续新增卡牌应优先复用现有字段和表现层；非追踪/穿透弹道、扇形伤害、死亡效果、眩晕/减速等仍属于需要独立设计和实现的机制，不应只靠增加一个数据字段假装完成。
