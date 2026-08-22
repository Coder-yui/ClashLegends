# 阶段 4 美术竖切规格

> 批量接入剑圣、亚索等普通近战 3D 角色时，执行
> [`docs/MELEE_3D_INTEGRATION.md`](MELEE_3D_INTEGRATION.md) 的完整清单。本文只保留
> 全项目通用的目录、动画合约和时序原则。

## 第一个竖切

盖伦已经跑通地面近战 3D 链路：部署、待机、移动、双普攻、命中时序、死亡表现和
联机同步。普通近战角色现在可以按复用流程逐个接入；盖伦仍缺的卡牌头像与受击表现
作为独立打磨项继续补齐，不再阻塞其他近战模型接入。

## 资源结构

```text
assets/
  README.md                    # 目录与接入约定
  units/<card_id>/
    source/                    # GLB、原始图等制作源文件
    <card_id>_view.tscn        # 3D 模型运行时包装场景
    <card_id>_frames.tres      # 可选的 2D SpriteFrames
  cards/<card_id>_portrait.png
  towers/
  arena/<arena_id>.png
  ui/
  fx/
  audio/
```

资源文件统一使用英文 `snake_case` 命名。单位目录名使用 `CardDB` 中稳定的
`card_id`，不使用可能变化的中文显示名。只在实际加入资源时创建目录，避免用
空目录和占位文件扩充结构。

当前已归档的源资源：

- `assets/arena/arena_default.png`：竞技场背景图。
- `assets/units/garen/source/garen.glb`：带骨骼、材质和 34 段动画的盖伦原始模型。
- `assets/units/garen/garen_view.tscn`：盖伦运行时包装场景，负责统一缩放与脚底原点。

## 动画合约

模拟层只输出以下固定表现状态：

- `deploy`
- `idle`
- `move`
- `attack`

死亡通过可靠的 `died` 表现事件触发，不是一个需要快照持续同步的状态。

3D 模型通过 `visual_animations` 将这些状态映射到 GLB 内部动画名。`attack`
可以配置为动作数组，盖伦使用 `["Attack1", "Attack2"]` 交替播放。卡牌数据增加
`"visual_scene_path": "res://assets/units/garen/garen_view.tscn"` 后，
`BattlePresentation3D` 会在透明 3D 视口中创建模型并镜像现有 `Unit` 的位置。

原有 `SpriteFrames` 表现仍可使用相同的 `deploy/idle/move/attack` 合约；缺少动画时自动回退到 `idle`。

## 尺寸原则

- `radius`：战斗物理半径，寻路、碰撞、攻击距离使用，不因换图改变。
- `visual_radius`：画面上的目标显示尺寸，可按素材调整。
- 塔额外有 `deployment_radius`：决定不可下兵的物理禁区，不应因精灵图的透明留白变大。

## 联机与时序

一套完整攻击动画（前摇、命中、后摇）的播放时长自动匹配 `attack_interval`，
`Attack1/Attack2` 在连续攻击时交替衔接。`first_hit` 表示从本轮攻击动画开始到
权威伤害命中的时间：盖伦当前为 `0.38 / 1.1 ≈ 35%`，因此命中比动画中点更早，
后半段主要用于收招。模拟层会在命中前 `first_hit` 秒产生递增的
表现序号，3D 层据此开始动画并在两套攻击之间做短 crossfade。

动画长度只决定播放倍率，不改变攻击间隔、伤害或命中判定。伤害仍由固定 tick
按 `first_hit` 计时结算，不得从动画回调触发。

单位死亡时，战斗节点会当帧退出 `combatants` 并释放，避免尸体继续参与碰撞、寻路
或伤害计算；3D 表现代理则独立播放一次 `death` 映射动画，播放结束后再移除。主机
通过可靠 RPC 同步死亡事件，快照缺席仍作为客户端兜底。

主机快照同步 `deploy/idle/move/attack` 表现状态、朝向和攻击表现序号，客户端只播放。当前 3D 客户端竖切按队伍推进方向显示；后续需要精确转向时再把完整朝向加入快照。伤害、命中、移动和碰撞仍由主机固定 20Hz 模拟决定，不得从动画帧回调触发。
