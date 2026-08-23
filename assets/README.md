# 美术资源目录

本目录只存放游戏美术与音频资源。资源文件统一使用英文 `snake_case` 命名；单位目录名必须与 `CardDB` 的 `card_id` 一致，例如盖伦使用 `garen`。

## 当前资源

```text
assets/
  arena/
    arena_default.png          # 竞技场背景（1200x1311）
  units/
    ashe/
      ashe_view.tscn          # 首个远程 3D 样例，Attack 离弦后生成蓝色小箭
      source/
        ashe.glb
    garen/
      garen_view.tscn         # 运行时 3D 包装场景（统一缩放与脚底原点）
      source/
        garen.glb              # 盖伦原始 3D 模型
    gwen/
      gwen_view.tscn          # 格温包装场景，已校正脚底高度
      source/
        gwen.glb
    sett/
      sett_view.tscn          # 瑟提包装场景，四段左右拳与右拳收势
      source/
        sett.glb
    teemo/
      teemo_view.tscn         # 提莫远程包装场景，暂用绿色短线毒针
      source/
        teemo.glb
  towers/
    princess/
      princess_tower_blue_view.tscn
      princess_tower_red_view.tscn
      source/                  # 蓝/红方塔 GLB 及导入纹理
    nexus/
      nexus_blue_view.tscn
      nexus_red_view.tscn
      source/                  # 蓝/红方水晶 GLB 及导入纹理
```

## 目录约定

```text
assets/
  arena/                       # 战场背景与场地资源
  units/<card_id>/
    source/                    # GLB、原始图等制作源文件
    <card_id>_view.tscn        # 直接使用 3D 模型时的运行时包装场景
    <card_id>_frames.tres      # 使用预渲染 2D 动画时的 SpriteFrames（可选）
  cards/<card_id>_portrait.png # 卡牌头像
  towers/                      # 塔与建筑表现
  ui/                          # 界面资源
  fx/                          # 特效资源
  audio/                       # 音乐与音效
```

仅在实际加入某类资源时创建对应目录，不为未使用的分类保留空文件夹。当前单位采用“2D 模拟 + 透明 3D 表现层”：原始模型保留在 `source/`，在同级包装场景中校正缩放和原点，再通过 `CardDB.visual_scene_path` 接入。`SpriteFrames` 方案继续作为低配置或特殊单位的可选路径。

添加新单位时：

1. 在 `scripts/data/card_db.gd` 确认其 `card_id`。
2. 将原始文件放入 `assets/units/<card_id>/source/`。
3. 创建 `assets/units/<card_id>/<card_id>_view.tscn`，在其中实例化源模型并校正缩放、朝向和脚底原点。
4. 在卡牌数据中设置 `visual_scene_path`、`visual_animations`，必要时设置 `visual_forward_yaw`；攻击动画会自动匹配该卡的 `interval`。
5. 不要让 3D 动画事件驱动伤害、碰撞或联网状态。

普通近战角色的完整操作步骤、验收项和排错方法见
[`docs/MELEE_3D_INTEGRATION.md`](../docs/MELEE_3D_INTEGRATION.md)。后续接入应复用现有
`BattlePresentation3D` / `UnitModel3D`，不要为每个角色复制表现脚本。

远程角色还需执行
[`docs/RANGED_3D_INTEGRATION.md`](../docs/RANGED_3D_INTEGRATION.md)，尤其要区分“动画
离弦时创建弹体”和“弹体抵达时结算伤害”。

防御塔和基地水晶同样采用“2D 权威节点 + 3D 表现代理”。双方素材分别使用明确的
`blue` / `red` 文件名；原始下载文件名中的 `(2)` 已归档为红方版本。塔的 `Base` 与
`Rubble`、水晶的 startup（`SRUAP_OrderNexus_Mat`）与 `Destroyed` 是同一网格中的
独立材质表面：存活时只显示前者，摧毁后切换到后者并播放摧毁动画。源模型 Y=0 以下
还有地下几何，运行时材质会按蒙皮后的世界坐标逐帧裁切，不能通过整体抬高模型来掩盖。
