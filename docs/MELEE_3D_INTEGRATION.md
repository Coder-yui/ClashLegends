# 近战角色 3D 素材接入流程

本文档供后续 agent 接入剑圣、亚索等近战角色时执行。盖伦已完成并验证整条链路，
应把它当作参考实现，而不是为每个角色复制一套动画系统。

## 适用范围

适用于已有 `CardDB` 单位数据、使用骨骼动画 GLB 的普通地面近战角色。当前通用层已经支持：

- 2D 权威模拟与透明 3D 表现叠加；
- 部署、待机、移动、攻击状态切换；
- 一套或多套普攻循环选择；
- 攻击动画自动匹配该单位的 `interval`；
- 使用 `first_hit` 对齐动画命中姿态与权威伤害时刻；
- 死亡动画、本地表现和可靠联机死亡事件；
- 失去目标、目标死亡或开始移动时平滑返回 Idle / Move。

如果角色拥有位移攻击、连招、蓄力、远程弹道、变身或技能动画，不要假设本流程已经
覆盖这些特殊机制，应先按普通近战完成基础接入，再单独定义玩法和表现需求。

瑟提是当前“分段普通攻击”参考：权威命中节奏由 `attack_pattern` 定义，Start / Hit /
Recover 动画仍只是数据映射。具体字段见 `docs/CARD_DESIGN.md` 的“分段普通攻击表现”，
不要把动画结束回调当成下一拳或伤害计时器。

## 不可破坏的边界

1. `Unit`、塔、碰撞、寻路和伤害仍是 2D 固定 tick 逻辑；3D 模型只负责显示。
2. 不得通过动画回调直接扣血，也不得用动画长度改变攻击间隔。
3. `radius`、`range`、`interval` 等是玩法数据，不能为了让模型“看起来合适”随意修改。
4. 单位先在 `CardDB` 选择七档 `size_tier` 与对应权威碰撞 `radius`；模型大小只在包装
   场景中调 `scale` 来匹配该档位，画面辅助尺寸使用 `visual_radius`。
5. 新角色正常不需要修改 `unit_model_3d.gd`、`battle_presentation_3d.gd`、`unit.gd`
   或死亡 RPC。先用数据映射解决差异，避免每个角色出现专用分支。
6. 新卡牌的玩法定义和数值仍遵循 `docs/CARD_DESIGN.md`，数值只放在
   `scripts/data/card_db.gd`。

## 接入前准备

先确认以下信息：

- 稳定的 `card_id`，例如 `masteryi`、`yasuo`；
- GLB 是否包含骨骼、蒙皮、材质和纹理；
- GLB 内实际的 AnimationPlayer 动画名；
- 至少一套 Idle、Run、Attack、Death；Deploy / Respawn 可以暂缺；
- 每套攻击动画中剑或武器真正接触目标的大致归一化时刻。

不要根据文件名猜动画名。先在 Godot 中打开导入后的 GLB，选中 AnimationPlayer，
逐个预览并记录名称、时长、是否循环、朝向和命中帧。不同批次的 LoL 提取素材命名
可能不同，也可能带前缀或大小写差异。

## 标准目录

```text
assets/units/<card_id>/
  <card_id>_view.tscn
  source/
    <card_id>.glb
    <模型依赖的纹理文件>
```

规则：

- 目录和自建文件统一使用英文 `snake_case`；
- 原始 GLB 及其外部纹理全部保留在 `source/`；
- 不手工编辑 Godot 生成的 `.import` 文件；
- 不直接从 `CardDB` 引用源 GLB，始终引用同级包装场景；
- 不提交重复导出的模型副本或无用途的临时预览文件。

盖伦参考：

```text
assets/units/garen/
  garen_view.tscn
  source/
    garen.glb
    garen_Garen_Base_Mat.png
```

## 步骤一：导入并检查源模型

把 GLB 和纹理放入目标目录后，让 Godot 完成导入，然后在编辑器中检查：

- 材质和纹理是否正常，没有粉色缺材质；
- 骨骼播放时网格没有飞散、错位或武器脱手；
- 模型脚底位置、初始朝向和整体尺寸；
- Idle / Run 是否适合循环；
- Attack 和 Death 是否为非循环动作，且加速播放后仍无骨骼错位；
- 多套普攻的名称和自然顺序。

素材有问题时优先修复导出或依赖文件，不要在战斗脚本中补偿损坏的骨骼或材质。

## 步骤二：创建包装场景

为角色创建 `assets/units/<card_id>/<card_id>_view.tscn`。包装场景只负责实例化源
模型并校正缩放、脚底原点等静态变换。盖伦的实际结构如下：

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://assets/units/garen/source/garen.glb" id="1_model"]

[node name="GarenView" type="Node3D"]

[node name="Model" parent="." instance=ExtResource("1_model")]
position = Vector3(0, -0.0195, 0)
scale = Vector3(0.015, 0.015, 0.015)
```

盖伦属于“大”档；新角色必须根据自己的模型和体型档位重新测量 `position` 与 `scale`，
不能照抄盖伦的数值。

当前人物包装场景在各自校准尺寸上统一应用 `1.5×`；带脚底 `position` 校正的角色必须
同步放大该偏移，避免只放大网格后悬空或下沉。权威碰撞仍是 `CardDB` 档位对应的圆柱，
不得从模型网格自动生成不规则碰撞体。

- 脚底应落在包装根节点的 `y = 0` 地面附近；
- 模型视觉高度应与同体型单位协调；
- 不要靠修改 2D `radius` 解决 3D 模型过大或过小；
- 血条会读取模型网格投影顶部自动放到人物头顶，不要在角色脚本里硬编码血条像素偏移；
- 朝向优先通过下方的 `visual_forward_yaw` 校正，避免包装场景和卡牌数据同时旋转。

## 步骤三：配置 CardDB 表现映射

在该角色已有的卡牌数据中增加表现字段。以下是模板，不要复制其中的玩法数值：

```gdscript
"<card_id>": {
    # 原有 hp / damage / range / speed / interval / first_hit 等玩法数据保持独立
    "visual_scene_path": "res://assets/units/<card_id>/<card_id>_view.tscn",
    "visual_forward_yaw": 0.0,
    "visual_animations": {
        "deploy": "<实际部署动画名>",
        "idle": "<实际待机动画名>",
        "move": "<实际跑步动画名>",
        "attack": ["<Attack1>", "<Attack2>"],
        "death": "<实际死亡动画名>",
    },
}
```

配置说明：

- 动画名区分大小写，必须与 GLB 的 AnimationPlayer 完全一致；
- 只有一套普攻时也可以写数组 `["Attack1"]`，也兼容单个字符串；
- 多套普攻按数组顺序循环，例如 1 → 2 → 1；三套则 1 → 2 → 3 → 1；
- `deploy` 部署动画按优先级选片：优先 `Respawn`（落点动画）；没有 `Respawn` 时
  用 Recall（回城）的收尾段（这类素材常命名为 `Recall_WindDown` / `Recall_Wind_Down`）；
  两者都没有时才退到 Idle。接入素材时优先确保 Respawn 存在，其次才是 Recall 收尾段；
- `deploy` 必须显式填写实际存在的动画名；若只能用 Idle 兜底，也把对应 Idle 名写进
  `deploy`。部署动画由通用层缩放到 `deploy_time` 时长播放，读条完成即解锁行动；
- 完整部署规则与赵信多段出场特例见 [`UNIT_DEPLOYMENT.md`](UNIT_DEPLOYMENT.md)；
- `idle`、`move` 由通用层设置为循环；Attack、Death 强制为非循环；
- `visual_forward_yaw` 使用弧度。模型完全背向时通常尝试 `PI`，侧向时尝试
  `PI / 2.0` 或 `-PI / 2.0`，以实际预览为准。

盖伦当前映射可直接作为字段结构参考：

```gdscript
"visual_animations": {
    "deploy": "Respawn_Base",
    "idle": "Idle1_Base",
    "move": "Run_Base",
    "attack": ["Attack1", "Attack2"],
    "death": "Death",
},
```

## 步骤四：对齐攻速和命中姿态

通用层会把一套完整攻击动画（前摇、命中、后摇）缩放到该角色的 `interval`。因此：

- `interval` 继续表示权威攻击周期；
- `first_hit` 表示从攻击动画开始到权威伤害命中的秒数；
- 动画开始、命中和下一次攻击均由固定 tick 战斗逻辑控制；
- 动画回调只处理表现结束，不参与伤害判定。

调校方法：

1. 在动画预览中找出武器接触目标的时间 `source_hit_time`；
2. 计算 `hit_ratio = source_hit_time / source_animation_length`；
3. 初值使用 `first_hit = interval * hit_ratio`；
4. 在游戏中连续攻击塔和普通单位，按观感小步调整 `first_hit`；
5. 同时检查第一击和连续攻击，不能只看某一帧截图。

普通近战的命中比例可先从攻击周期的 25%～40% 尝试，但最终必须以素材中的接触姿态
为准。盖伦当前是 `0.38 / 1.1 ≈ 35%`。战斗模拟为 20Hz，实际结算会落在 0.05 秒
的模拟 tick 上，不要为小于一个 tick 的差异过度调参。

不要通过以下方式“修复”命中观感：

- 把伤害放到 AnimationPlayer 的 method track；
- 修改 `interval` 来迎合原始动画时长；
- 为某个角色复制一套攻击计时器；
- 在表现脚本中直接调用 `take_damage()`。

## 步骤五：检查死亡表现

只要映射了 `"death"`，通用死亡链路会自动工作：

1. 单位死亡当帧退出 `combatants`，解除建筑占地并释放 2D 战斗节点；
2. 3D 代理隐藏队伍圆环，停用生前状态同步；
3. 播放非循环 Death，并通过 `visual_animations.death_duration` 对齐统一表现时长；
4. 动画结束后清理纯视觉代理；
5. 主机通过可靠 RPC 通知客户端，快照缺席作为兜底。

当前统一规则是英雄 0.8 秒、小兵 0.5 秒。该时长只缩放素材播放速度，不改变单位死亡
当帧退出战斗的权威逻辑。

新角色不应再次修改 `Unit._die()` 或新增角色专用死亡 RPC。若没有 Death 动画，当前
行为是直接清理模型；这不算该角色完成了美术接入。

## 步骤六：验证

### 编辑器内目视检查

用 Godot 4.x 打开项目并按 F5，至少确认：

- 部署后模型尺寸、脚底和队伍方向正确；
- Idle 不抖动，Run 不滑步或反向跑；
- 接近目标后停止距离合理，武器命中姿态与掉血基本一致；
- 多套 Attack 按配置顺序循环，没有突然切回 Idle；
- 目标死亡、脱离攻击和开始移动时能自然回到基础状态；
- 自身死亡时播放 Death，尸体期间不会阻挡、攻击或被再次选中；
- 玩家队和敌队均朝向正确；
- 攻击普通单位、建筑卡和塔都能播放动作并造成伤害。

### 机制回归

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script tests/mechanics_check.gd
```

为新角色增加最小回归检查时，应验证包装场景能加载、必要动画名存在、攻击映射顺序和
Death 能触发；不要在测试里重新实现一遍动画系统。

### 联机冒烟测试

分别启动主机和客户端：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . -- --mode=host --auto-test

/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path . -- --mode=join --ip=127.0.0.1 --auto-test
```

确认客户端收到生成和快照，攻击动画序号正常推进，单位死亡后播放 Death 而不是直接
消失。当前自动样本不一定包含新角色；如新角色不在默认出兵样本中，应通过正常部署
流程验证，或为它补充明确、可长期保留的测试样本，不能只证明盖伦仍然工作。

## 常见问题

### 模型不可见

- 检查 `visual_scene_path` 是否存在且指向包装 `.tscn`；
- 检查包装场景的模型 `scale`，LoL 提取模型常需要较小倍率；
- 检查模型是否因脚底偏移落在地面以下；
- 检查 GLB 和外部纹理是否已被 Godot 正常导入。

### 模型方向错误

只调整 `visual_forward_yaw`，依次尝试 `PI`、`PI / 2.0`、`-PI / 2.0`。确认玩家队、
敌队、移动和锁定目标四种情况后再定值，不要只看出生朝向。

### 动画不播放

- 动画名可能存在大小写、前缀或后缀差异；
- 确认 AnimationPlayer 位于 GLB 节点树内，通用层会递归查找；
- 确认 Attack 是字符串或非空数组；
- 先直接预览源 GLB，排除骨骼或导入错误。

### 攻击掉血早或晚

只微调该卡的 `first_hit`，不要改通用动画播放代码。先核对素材命中比例，再同时观察
第一击、连续攻击、攻击塔和转移目标四种情况。

### 死亡后直接消失

检查 `visual_animations.death` 是否存在、名称是否准确、动画是否非空。若本地正常而
客户端异常，再检查可靠死亡 RPC；不要新增角色专属网络字段。

### 动作切换仍明显跳变

先判断是否是源动画首尾骨骼姿态差异过大。当前通用层已提供短 crossfade，并让完整
攻击动作匹配攻击周期；不要为了单一素材立即重构状态机。记录具体动画和复现条件后，
再评估是否需要通用的逐角色 blend 配置。

## Agent 交付清单

接入一个近战角色时，最终回复必须说明：

- 新增了哪些源资源和包装场景；
- 实际使用的 Idle / Run / Attack / Death 动画名；
- `scale`、脚底偏移和 `visual_forward_yaw`；
- `interval`、`first_hit` 和命中比例；
- 本地目视、机制回归和联机验证结果；
- 仍缺少的动画、纹理、头像、音效或特殊机制。

除非用户明确要求，不要顺手接入其他角色、重做竞技场或修改玩法平衡。
