# 普通远程模型：相对近战的差异

先完成 `MELEE_3D_INTEGRATION.md`。本文只补充离弦、弹体和命中时序。

```text
权威攻击序号/动画开始
  → first_hit 到时创建主机权威弹体（离弦）
  → ProjectileSystem 固定 Tick 追踪飞行
  → 抵达目标碰撞圈
  → 结算伤害/命中被动
```

`first_hit` 对远程单位是离弦时刻，不是伤害时刻。动画回调不能创建权威弹体或扣血。

```gdscript
"projectile_speed": 480.0,
"projectile_visual": "arrow",
"projectile_visual_height": 45.0,
"projectile_visual_forward_offset": 0.0,
```

当前实现支持：`orb`（圆形法球）、`arrow`（带箭头细箭）、`needle`（短针）、`boomerang`（V 形回旋镖占位）。`projectile_speed` 必须大于 0；高度和前向偏移只改变绘制起点，不改变权威轨迹/飞行时间/命中。双阵营颜色用两个 Color 的 `projectile_colors`。

调校步骤：预览 Attack → 找离弦源时刻 → `first_hit = interval × release_ratio` → 以 0.05 秒 Tick 目视微调。验收发射时不扣血、命中才扣血；目标死亡/失效/缠流拦截时弹体消失；箭头方向正确；塔/单位/建筑均可命中；host/client 的类型、方向、高度一致。
