# 阶段 4 美术竖切规格

> 批量接入剑圣、亚索等普通近战 3D 角色时，执行
> [`docs/MELEE_3D_INTEGRATION.md`](MELEE_3D_INTEGRATION.md) 的完整清单。本文只保留
> 全项目通用的目录、动画合约和时序原则。
>
> 接入寒冰等远程角色时，额外执行
> [`docs/RANGED_3D_INTEGRATION.md`](RANGED_3D_INTEGRATION.md) 的离弦、弹体与联机验收。

## 第一个竖切

盖伦已经跑通地面近战 3D 链路：部署、待机、移动、双普攻、命中时序、死亡表现、
受击闪白和联机同步。普通近战角色现在可以按复用流程逐个接入；盖伦仍缺卡牌头像，
不再阻塞其他模型接入。

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
    princess/
      source/princess_tower_blue.glb
      source/princess_tower_red.glb
      princess_tower_blue_view.tscn
      princess_tower_red_view.tscn
    nexus/
      source/nexus_blue.glb
      source/nexus_red.glb
      nexus_blue_view.tscn
      nexus_red_view.tscn
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
- `assets/towers/princess/`：蓝红双方防御塔，包含出生、待机、摧毁和 Rubble 废墟。
- `assets/towers/nexus/`：蓝红双方基地水晶，包含 startup、Destroyed 表面及出生/死亡动画。

## 防御塔与基地水晶

`Tower` 继续保存血量、攻击、碰撞和联网权威状态；`TowerModel3D` 只镜像屏幕位置、
阵营朝向及一次性的摧毁表现。蓝方建筑朝向画面上方的红方，红方建筑朝向画面下方的
蓝方。客户端从塔血量快照检测存活到摧毁的跃迁，幂等地补播同一摧毁事件。

这批 GLB 把存活与废墟几何做在同一张蒙皮网格中，并用不同材质表面区分：防御塔为
`Base` / `Rubble`，水晶为 startup（`SRUAP_OrderNexus_Mat`）/ `Destroyed`。
出生和待机阶段只显示存活表面；摧毁时切换为废墟表面、播放 `Destroyed` / `Death`，
结束后停在最后一帧。素材地面以下的塔基和待机废墟不能出现在画面中，因此专用材质
按每帧蒙皮后的世界 Y 高度裁切，而不是删除源网格或整体抬高模型。

表面切换与动画只负责显示；塔在何时失去碰撞、何时停止攻击、胜负与伤害结算仍完全
由固定 tick 的 2D 模拟决定。

## 动画合约

模拟层只输出以下固定表现状态：

- `deploy`
- `idle`
- `move`
- `attack`

死亡通过可靠的 `died` 表现事件触发，不是一个需要快照持续同步的状态。
受击同样通过可靠表现事件触发：所有 3D 单位短暂叠加 42% 半透明白色约 0.06 秒后恢复；闪白
不产生硬直，也不参与伤害、仇恨或模拟计时。持续伤害会限制闪白事件频率，避免模型
一直纯白或向客户端发送过密的可靠 RPC。

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
`Attack1/Attack2` 在连续攻击时交替衔接。近战的 `first_hit` 表示从本轮攻击动画开始到
权威伤害命中的时间：盖伦当前为 `0.38 / 1.1 ≈ 35%`，因此命中比动画中点更早，
后半段主要用于收招。模拟层会在命中前 `first_hit` 秒产生递增的
表现序号，3D 层据此开始动画并在两套攻击之间做短 crossfade。

远程单位的 `first_hit` 表示动画开始到弹体离弦的时间；离弦只创建弹体，伤害必须等
弹体抵达目标碰撞圈后结算。

动画长度只决定播放倍率，不改变攻击间隔、伤害或命中判定。伤害仍由固定 tick
按 `first_hit` 计时结算，不得从动画回调触发。

单位死亡时，战斗节点会当帧退出 `combatants` 并释放，避免尸体继续参与碰撞、寻路
或伤害计算；3D 表现代理则独立播放一次 `death` 映射动画，播放结束后再移除。主机
通过可靠 RPC 同步死亡事件，快照缺席仍作为客户端兜底。

主机快照同步 `deploy/idle/move/attack` 表现状态、朝向和攻击表现序号，客户端只播放。当前 3D 客户端竖切按队伍推进方向显示；后续需要精确转向时再把完整朝向加入快照。伤害、命中、移动和碰撞仍由主机固定 20Hz 模拟决定，不得从动画帧回调触发。
