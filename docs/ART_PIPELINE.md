# 阶段 4 美术竖切规格

> 批量接入剑圣、亚索等普通近战 3D 角色时，执行
> [`docs/MELEE_3D_INTEGRATION.md`](MELEE_3D_INTEGRATION.md) 的完整清单。本文只保留
> 全项目通用的目录、动画合约和时序原则。
>
> 接入寒冰等远程角色时，额外执行
> [`docs/RANGED_3D_INTEGRATION.md`](RANGED_3D_INTEGRATION.md) 的离弦、弹体与联机验收。

## 第一个竖切

盖伦已经跑通地面近战 3D 链路：部署、待机、移动、双普攻、命中时序、死亡表现、
受击闪白和联机同步。普通近战角色现在可以按复用流程逐个接入；英雄卡面优先使用
CommunityDragon 的原生 Loading Screen。

## 资源结构

```text
assets/
  README.md                    # 目录与接入约定
  units/<card_id>/
    source/                    # GLB、原始图等制作源文件
    <card_id>_view.tscn        # 3D 模型运行时包装场景
    <card_id>_frames.tres      # 可选的 2D SpriteFrames
  cards/<card_id>_loading.png
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

## Agent 标准接入流程

接入新卡美术时，建议先让卡牌用占位表现跑通，再按以下顺序加入资源。这样模型导入失败不会掩盖玩法或联机问题。

### 1. 建立资源目录并检查源文件

1. 确认 `card_id` 已存在于 `scripts/data/card_db.gd`，目录名和文件名均使用英文 `snake_case`。
2. 按以下优先级准备卡面：英雄使用 CommunityDragon 基础皮肤 Loading Screen；有模型但没有
   原生图像时，用统一摄影棚拍 3D 模型；两者都没有时，使用 AI 生成图像。最终文件放到
   `assets/cards/<card_id>_loading.jpg/png/webp`，没有正式卡面时 UI 才显示数据色占位。
3. GLB 和外部纹理全部放到 `assets/units/<card_id>/source/`。不要手工编辑 `.import` 文件，不要把临时截图、重复导出或源文件放在运行时目录。
4. 让 Godot 完成导入后，在编辑器中打开源 GLB，确认材质、骨骼、脚底、朝向和 `AnimationPlayer` 动画名。动画名区分大小写，必须记录真实名称。

### 2. 创建运行时包装场景

创建 `assets/units/<card_id>/<card_id>_view.tscn`，包装场景只负责实例化 GLB、设置静态 `scale`、脚底 `position` 和必要的朝向。不要把权威碰撞体、寻路或伤害脚本挂到模型上；这些仍由 `Unit` 和 `CardDB` 管理。

模型大小根据同体型单位目视校准，战斗半径使用 `CardDB` 七档 `radius`。如果模型悬空或下沉，同时调整包装场景的缩放和脚底偏移，不要修改 `radius` 迎合素材。

### 3. 配置 CardDB 表现字段

在卡牌条目中填写：

```gdscript
"visual_scene_path": "res://assets/units/<card_id>/<card_id>_view.tscn",
"visual_forward_yaw": 0.0,
"visual_animations": {
    "deploy": "<实际出场或 Idle 动画名>",
    "idle": "<实际待机动画名>",
    "move": "<实际移动动画名>",
    "attack": ["<实际攻击动画名>"],
    "death": "<实际死亡动画名>",
},
```

双方有不同模型时使用 `visual_scene_paths = [order_scene, chaos_scene]`。近战按 [`MELEE_3D_INTEGRATION.md`](MELEE_3D_INTEGRATION.md) 执行，远程还必须按 [`RANGED_3D_INTEGRATION.md`](RANGED_3D_INTEGRATION.md) 配置离弦时刻、弹体类型和绘制高度。所有手牌的出场动画都要遵循 [`UNIT_DEPLOYMENT.md`](UNIT_DEPLOYMENT.md) 的 0.5 秒卡牌延迟和 `deploy_time` 规则。

### 4. 按层验收

先运行 `Godot --headless --path . --script tests/mechanics_check.gd`，再按 F5 实际检查：

- 卡面、卡组选择、手牌和卡牌占位是否正确；
- 部署后脚底、尺寸、蓝红朝向和血条顶部是否正确；
- Idle / Move / Attack / Death 是否都能播放，攻击命中时刻是否与 `first_hit` 一致；
- 近战是否在权威攻击时刻掉血，远程是否先离弦、弹体到达后才掉血；
- 死亡表现结束前，2D 单位是否已经退出碰撞、寻路和伤害系统；
- 塔、普通单位、建筑、主机和客户端视角是否都正常。

联机表现不能只看模型是否出现，还要确认生成、快照、朝向、攻击序号、弹体、受击闪白和死亡事件在客户端一致。新卡没有被自动测试样本使用时，必须通过实际卡组或美术开发面板手动部署验证。

### 5. Agent 交付记录

交付时写明：资源路径、包装场景、实际动画名、`scale`/脚底偏移/`visual_forward_yaw`、`first_hit` 调校值、卡面格式，以及 headless、F5 和 host/join 的结果。尚缺资源或特殊机制要明确列出，不要用“已接入”掩盖缺失项。
