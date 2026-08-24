# 美术资源目录

本目录只存放游戏美术与音频资源。资源文件统一使用英文 `snake_case` 命名；单位目录名必须与 `CardDB` 的 `card_id` 一致，例如盖伦使用 `garen`。

如果是为新卡接入资源，请先阅读 [`docs/AGENT_WORKFLOW.md`](../docs/AGENT_WORKFLOW.md) 的完整 Agent 流程，再按本文件的目录和命名约定操作；本文只描述资源归档，不替代卡牌玩法和联网回归要求。

## 当前资源

```text
assets/
  arena/
    arena_rift_v4.png          # 当前竞技场背景（720x1400，干净场地与符文之地场外景观）
    arena_default.png          # 旧版竞技场概念图（1200x1311）
  units/
    ashe/
      ashe_view.tscn          # 首个远程 3D 样例，Attack 离弦后生成蓝色小箭
      source/
        ashe.glb
    aurelionsol/
      aurelionsol_view.tscn   # 首个空中 3D 单位，持续吐息与四段飞行动画循环
      source/
        aurelionsol.glb
        aurelionsol_AurelionSol_BodyLower.png
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
    melee_minion/
      melee_minion_order_view.tscn / melee_minion_chaos_view.tscn
      source/                  # order=蓝方、chaos=红方
    ranged_minion/
      ranged_minion_order_view.tscn / ranged_minion_chaos_view.tscn
      source/                  # 权杖发射阵营色小光球
    siege_minion/
      siege_minion_order_view.tscn / siege_minion_chaos_view.tscn
      source/                  # 炮口发射黑色小球
    super_minion/
      super_minion_order_view.tscn / super_minion_chaos_view.tscn
      source/
  cards/
    <card_id>_loading.jpg/png  # 英雄 Loading Screen、模型摄影或法术插画卡面
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
  units/tombstone/
    tombstone_view.tscn        # 墓碑 3D 包装场景，五层流动黑雾覆盖地面与模型内部
    source/tombstone.glb       # 牧魂人（1）墓碑模型及其材质
  units/imp/
    imp_view.tscn              # 小鬼 3D 包装场景（Run1 移动 / leapWindup 攻击）
    source/imp.glb             # 牧魂人小鬼模型及其材质
  cards/<card_id>_loading.jpg  # 英雄基础皮肤 Loading Screen；UI 自动按比例 cover 裁剪
  towers/                      # 塔与建筑表现
  ui/                          # 界面资源
  fx/                          # 特效资源
  audio/                       # 音乐与音效
```

仅在实际加入某类资源时创建对应目录，不为未使用的分类保留空文件夹。当前单位采用“2D 模拟 + 透明 3D 表现层”：原始模型保留在 `source/`，在同级包装场景中校正缩放和原点，再通过 `CardDB.visual_scene_path` 接入；同一玩法单位有 order/chaos 两套模型时使用 `visual_scene_paths = [order, chaos]`。`SpriteFrames` 方案继续作为低配置或特殊单位的可选路径。

卡牌图片统一使用 `assets/cards/<card_id>_loading.jpg` 或 `.png` 命名。`CardArt` 会按同一规则自动查找
`jpg`、`png` 或 `webp`，因此新增英雄卡时只需将基础皮肤 `loadScreenPath` 图片放入该目录；
手牌和选卡组按钮会使用 `KEEP_ASPECT_COVERED` 保持比例，从中心裁剪 Loading Screen。
统一卡框比例为 CommunityDragon 当前 Loading Screen 的 `308:560`；不同界面只缩放高度，保持同一套框形。

四类兵线卡面直接由项目内 Order 阵营 3D 模型拍摄，源模型更新后运行
`Godot --path . --script tools/capture_minion_card_art.gd` 即可按统一摄影棚、灯光和 `308×560`
尺寸重新生成；该工具只写入卡面 PNG，不参与运行时表现或战斗逻辑。

墓碑卡面由正式墓碑、小鬼模型和运行时黑雾共同拍摄；更新相关模型或雾效后运行
`Godot --path . --script tools/capture_tombstone_card_art.gd` 重新生成
`assets/cards/tombstone_loading.png`。

添加新单位时：

1. 在 `scripts/data/card_db.gd` 确认其 `card_id`。
2. 将原始文件放入 `assets/units/<card_id>/source/`。
3. 创建 `assets/units/<card_id>/<card_id>_view.tscn`，在其中实例化源模型并校正缩放、朝向和脚底原点。
4. 在卡牌数据中设置 `visual_scene_path`、`visual_animations`，必要时设置 `visual_forward_yaw`；攻击动画会自动匹配该卡的 `interval`。
5. 不要让 3D 动画事件驱动伤害、碰撞或联网状态。

每个角色接入前还必须按
[`docs/UNIT_DEPLOYMENT.md`](../docs/UNIT_DEPLOYMENT.md) 检查部署动画：优先选素材中的
Respawn，其次 Recall-Winddown，最后才用 Idle，并在卡牌数据中显式填写实际动画名。

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
