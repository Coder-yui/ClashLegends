# 阶段 4 美术竖切规格

## 第一个竖切

先只导入一个地面单位（建议盖伦），验证一条完整链路：卡牌头像 → 部署 → 待机 → 移动 → 攻击 → 受击/死亡表现。竖切验证完成前不批量处理其他卡。

## 资源结构

```text
assets/
  units/<card_id>/
    source/                 # 原始图，不直接被场景引用
    <card_id>_frames.tres   # Godot SpriteFrames
  cards/<card_id>_portrait.png
  towers/
  arena/
  ui/
  fx/
  audio/
```

## 动画合约

`SpriteFrames` 使用固定动画名：

- `deploy`
- `idle`
- `move`
- `attack`

可以暂缺 `deploy/move/attack`，程序会回退播放 `idle`。卡牌数据增加
`"visual_frames_path": "res://assets/units/garen/garen_frames.tres"` 即可启用美术表现。

## 尺寸原则

- `radius`：战斗物理半径，寻路、碰撞、攻击距离使用，不因换图改变。
- `visual_radius`：画面上的目标显示尺寸，可按素材调整。
- 塔额外有 `deployment_radius`：决定不可下兵的物理禁区，不应因精灵图的透明留白变大。

## 联机与时序

主机快照同步 `deploy/idle/move/attack` 表现状态和朝向，客户端只播放。伤害、命中、移动和碰撞仍由主机固定 20Hz 模拟决定，不得从动画帧回调触发。
